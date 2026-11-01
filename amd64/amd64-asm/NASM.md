# NASM-derived instruction table

> The amd64 encoder now has two layers: a small set of handwritten special
> forms (`insn.rkt`) and a generated legacy/x86 table (`insn-generic.rkt` +
> `generated/gen/insn/nasm.rkt`).  The generated layer is built from NASM's
> authoritative `x86/insns.dat`.

## 1. Why

The old table was hand-written. It was correct for the forms the compiler
happened to use, but incomplete: `adc/sbb`, `shld/shrd`, bit-test families,
`movbe`, `lzcnt/tzcnt`, most SSE/SSE2 forms, CRC32, and many system
instructions were missing.

The replacement follows the same separation that `riscv/riscv-asm` uses:

```text
authoritative source
  nasm/insns.dat
        |
        v  NASM x86/preinsns.pl (upstream, run once when refreshing)
  nasm/insns.pre.dat      ; macros expanded, four fields per line
        |
        v
  binary-build/parse.rkt  ; raw lines -> operands + encoding tokens
        |
        v
  binary-build/resolve.rkt; 64-bit/GPR/XMM support filter + limits
        |
        v
  binary-build/emit/table.rkt
        |
        v
  generated/gen/insn/nasm.rkt
        |
        v
  insn-generic.rkt        ; matcher + byte emitter shared with insn.rkt
```

`insn.rkt` keeps its existing special plans because they encode public
forms that are not one-to-one with NASM rows: `jmp-short`, `jcc-near`,
`call-indirect`, `prefix`, the conditional-code pseudo forms `jcc`, `setcc`,
`cmovcc`, and the `mov` immediate-selection policy.  Everything without a
special entry goes through the generated table.

## 2. Source provenance

| Item | Value |
| --- | --- |
| Upstream | `https://github.com/netwide-assembler/nasm` |
| File | `x86/insns.dat` |
| Commit | `fbdc88565ccccfa0e8c69b21b1953d1eded02e89` |
| License | BSD-2-Clause, see `nasm/LICENSE` |
| Checked-in raw source | `nasm/insns.dat` |
| Checked-in preprocessed snapshot | `nasm/insns.pre.dat` |

Refresh steps (requires Perl, only when updating the snapshot):

```bash
git clone https://github.com/netwide-assembler/nasm.git /tmp/nasm
cd /tmp/nasm
perl -I. x86/preinsns.pl x86/insns.dat /tmp/insns.pre.dat
cp x86/insns.dat  /path/to/amd64/amd64-asm/nasm/insns.dat
cp /tmp/insns.pre.dat /path/to/amd64/amd64-asm/nasm/insns.pre.dat
```

Then update `upstream-commit` in `binary-build/emit/package.rkt`, regenerate,
and rerun `amd64/run-tests.sh`.

## 3. Data model

`binary-build/model.rkt` keeps the build-time representation deliberately
small:

- `raw-line`: mnemonic, operands, parsed encoding, NASM flags, source line.
- `operand-def`: public operand kind (`gpr`, `gpr-fixed`, `rm`, `mem`, `xmm`,
  `xmm-rm`, `imm`), width, fixed register name.
- `encoding-def`: mandatory prefixes, opcode bytes, `+r`, ModR/M roles,
  immediates, operand-size mode, `nw`, REX bits.
- `form`: a supported entry after resolution.
- `skipped`: source line + explicit rejection reason.

The build never silently drops a line.  A refresh prints every rejection
class, for example:

```text
emitted forms:        1264
rejected forms:       480
  196: unsupported flag: UNDOC
  140: unsupported flag: FPU
   65: unsupported flag: NOLONG
   32: unsupported operand class (rel/unity)
   32: control form belongs to insn.rkt
```

Rejected classes are intentional:

- x87/FPU and MMX (no register model)
- AVX/AVX2/AVX-512/EVEX/APX/XOP/AMX/MPX (VEX/EVEX encoding not implemented)
- `NOLONG` forms (not valid in 64-bit mode)
- relative-control rows (`rel*`); control forms stay in `insn.rkt`
- multiple-immediate and unsupported operand shapes

## 4. Constraint checking vs. instruction generation

The split exists at both build time and runtime.

### Build time

```text
parse.rkt     source syntax only
resolve.rkt   supported-form constraints + rejection reasons
emit/table.rkt render the surviving rows; no semantic decisions
```

`emit/table.rkt` never decides whether a form is legal.  It only serializes
forms that `resolve.rkt` already accepted.

### Runtime

`insn-generic.rkt` turns each generated row into an `entry` and groups entries
by mnemonic.  A separate plan stage performs every constraint/policy check:

```text
operands
  -> generic-plan-instruction
       try-plan-entry: arity, operand kinds/widths, immediate range,
                       operand-size prefix, REX.W/REX bits, high-byte check,
                       ModR/M + SIB addressing validation
       choose shortest candidate; ties retain NASM source order
  -> instruction-plan      (fixed form, prefixes, opcode, RM plan,
                            immediate width/value, size)
  -> encode-plan           (concatenate bytes only)
```

The important boundary:

- `generic-plan-instruction` / `try-plan-entry` are the **checking/selection**
  stage.  They return a plan or reject a candidate.
- `plan-size` answers layout's size question from the plan.
- `encode-plan` is **generation only**.  It re-checks no operands and makes no
  form-selection decisions.
- `generic-instruction-size` is what `instruction-size` uses for generic-only
  mnemonics, so layout does not need to emit bytes.
- `generic-encode-instruction` is `(encode-plan (generic-plan-instruction ...))`.
- `plan.rkt` wraps generated and handwritten special forms in one
  `resolved-plan`; `insn.rkt` exposes `instruction-plan`, `plan-size` and
  `encode-plan` on top of that.

Shortest-candidate selection is why `(adc rax 200)` uses the accumulator
form (`48 15 c8 00 00 00`) while `(adc rax 1)` uses the sign-extended byte
form (`48 83 d0 01`), matching NASM/LLVM behavior.

The plan stage shares `insn-core.rkt` with the handwritten path, so ModR/M,
SIB, REX, high-byte register checks, displacement and immediate range rules
have one implementation.  `insn-core.rkt` is also what makes `rm-encoding` a
plan fragment rather than an ad-hoc encoder decision.

## 5. Build

```bash
cd amd64/amd64-asm
make build          # racket binary-build/main.rkt
make test           # build + local tests
make clean          # remove generated/gen
```

Options:

```bash
racket binary-build/main.rkt --source nasm/insns.pre.dat
racket binary-build/main.rkt --output /tmp/amd64-generated
racket binary-build/main.rkt --clean
racket binary-build/main.rkt --help
```

`--output` still works because generated rows are plain quoted data; the
generated module does not hard-code a require path back into the build tree.

## 6. Adding or checking a form

1. Check NASM source first (`nasm/insns.pre.dat`, `grep '^MNEMONIC '`).
2. If the form is a generic ModR/M/immediate/prefix form, it should already
   be emitted after a refresh.  Add a golden test in `test-generated.rkt` and
   an oracle case in `test-oracle.rkt`.
3. If the form needs a public spelling that NASM does not have (`jmp-short`,
   `jcc`, `setcc`, `prefix`, ...), add a special family under `amd64-asm/special/` and register its plan in `special/table.rkt`
   instead of distorting the table.
4. If a whole source family is rejected, change `resolve.rkt` only when the
   runtime matcher actually supports its operand/encoding classes.

## 7. Current boundary

Supported generated families include:

- integer ALU/carry/borrow, shifts/rotates, multiply/divide forms
- bit test/scan/change, double shifts, bit counting
- `movbe`, `crc32`, `cmpxchg8b/16b`
- SSE/SSE2 legacy forms with GPR/XMM/memory/imm8 operands
- legacy fixed-opcode system instructions without special implicit state
- segment-selector style rows such as `verr/verw`, and `/digit` memory rows
  such as `sgdt/sidt/invlpg`

Still outside the generated table:

- x87/MMX
- AVX/VEX/EVEX/APX and vector widths above 128 bits
- 16/32-bit mode, segment registers, far transfers
- forms with multiple immediates, `mem_offs`, MIB/VSIB, conditional-code
  pseudo mnemonics
