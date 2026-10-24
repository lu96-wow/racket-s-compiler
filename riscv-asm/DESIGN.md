# Design Notes

## 1. Goals

The rebuild has four explicit goals:

1. One source of truth for each kind of knowledge.
2. Make encoding identity, operand interface, and provenance separate concepts.
3. Keep generated runtime packages self-contained and extension-scoped.
4. Make illegal states fail loudly during build, not silently at runtime.

Non-goals:

- Generating raw bit layouts from `arg_lut.csv`
- Supporting 48-bit or longer instructions
- Providing a cross-extension aggregate table

---

## 2. Pipeline

```text
riscv-opcodes/extensions/*
        |
        v
binary-build/parse.rkt
  fixed-field / instruction-def / pseudo-def / import-def / extension-file
        |
        v
binary-build/resolve.rkt
  candidate selection + origin + resolved-def + skipped-definition
        |
        +-----------------------------+
        |                             |
        v                             v
binary-build/layout/plan.rkt              binary-build/emit/metadata.rkt
  raw/rebuilt operand plan         instruction-info
        |                             |
        v                             v
binary-build/emit/instruction.rkt         generated/gen/riscv/info/*.rkt
  raw/rebuilt modules
        |
        v
generated/gen/riscv/instruction/*/*.rkt
```

`binary-build/layout/groups.rkt` feeds both `plan.rkt` and `binary-build/emit/fields.rkt`.
`binary-build/paths.rkt` is the only module that knows the output directory layout.

---

## 3. Data model

### Parse structures

- `fixed-field`: `[lo, hi] = value`
- `instruction-def`: source name, ordered operand tokens, fixed fields
- `pseudo-def`: source extension/instruction + instruction-def
- `import-def`: source extension/instruction
- `extension-file`: standard + pseudo + imports

The parser deliberately does **not**:

- merge `imm12hi` / `imm12lo`
- rename tokens
- infer semantic operands from token names

### Resolution structures

- `candidate`: definition + kind + origin + optional pseudo source
- `resolved-def`: definition + origin
- `skipped-definition`: name + reason

### Runtime structures

`instruction-info` stores:

- public operand sequences: `operands`, `raw-operands`
- source fixed fields: `fixed-fields`
- alias relations: `aliases`
- provenance: `origin`
- actual raw/rebuilt field bindings: `raw-bindings`, `rebuilt-bindings`

The bindings are generated from the same operand plans that generate the
instruction modules. Runtime signature comparison therefore does not need to
re-derive field mappings from token names.

---

## 4. Grouping registry

`binary-build/layout/groups.rkt` is the only place that declares:

```text
logical operand name -> (module, raw token list)
```

It is used by:

- `rebuilt-operand-plan`
- generated rebuilt field modules
- metadata generation
- tests

This removes the old duplication where rebuilt modules and codegen both had to
know that e.g. `simm12 = imm12hi + imm12lo`.

---

## 5. Candidate priority and conflicts

Priority:

```text
3  standard definition in this extension
2  imported standard definition
1  pseudo whose fixed fields are compatible with its source
0  other pseudo
```

Rules:

- Imports resolve only against the source extension's standard definitions.
- Pseudo sources must be standard definitions.
- Multiple candidates with the same highest priority are a build error.
  Picking the first silently would make builds non-reproducible.
- Lower-priority losers are recorded as skipped definitions with a reason.

Origin is recorded but does not affect priority within a single extension beyond
the rules above.

---

## 6. Canonical runtime signatures

### Encoding signature

```text
width
+ actual fixed word
+ canonical raw bindings
+ canonical rebuilt bindings
```

Fixed fields are folded into a single word using the same `bitwise-ior`
semantics as generated `make-instruction` code. This makes these equivalent:

```text
31..25=0
31..26=0 25..25=0
```

Bindings are sorted and de-duplicated because field OR order does not matter.

Excluded from encoding identity:

- instruction name
- extension
- `asm`
- `size` (derived from width)
- provenance

### Interface signature

```text
operands order
+ raw-operands order
+ canonical aliases
```

Operand order is intentionally order-sensitive: it is the public calling
convention of the generated instruction procedure.

### Provenance signature

```text
kind + source-extension + source-instruction
```

Provenance is for diagnostics/policy. It never causes two identical encodings to
be treated as conflicting.

---

## 7. Lookup and disambiguation

`resolve-instruction-info`:

1. validates argument types
2. rejects mixed `rv32_*` / `rv64_*` extension sets
3. collects candidates by extension order
4. requires all candidates to have equal encoding signatures
5. requires all candidates to have equal interface signatures
6. chooses by origin priority: standard > import > pseudo

This means:

- `andn` from `rv_zbb` (standard) and `rv_zbkb` (import) deduplicates
- `zip` from `rv32_zbkb` (standard) and `rv32_zk` (pseudo) deduplicates
- `slli` from `rv32_i` and `rv64_i` is a hard error
- an rv32/rv64 mix is rejected even if some names would have equal encodings

---

## 8. Output package

```text
generated/
  lib/                          copied runtime modules
    base.rkt
    bit.rkt
    instruction_paths.rkt
    riscv/raw/*.rkt
    info/
      struct.rkt
      query.rkt
      lookup.rkt
  gen/                          generated modules
    riscv/
      field/rebuilt/*.rkt       generated from groups.rkt
      instruction/raw/*.rkt
      instruction/rebuilt/*.rkt
      info/
        <extension>.rkt
        extensions.rkt
        instruction_extensions.rkt
```

`lib/` and `gen/` are the complete ownership boundary of the build. Cleaning
removes only those two directories.

---

## 9. Invariants checked by tests

- Every resolved definition appears in info, raw, and rebuilt modules.
- No module exports an instruction absent from metadata.
- Metadata raw/rebuilt bindings equal the plans recomputed from source.
- Metadata origin equals the resolver's origin.
- Every info has a valid width and `size == width / 8`.
- Known skipped definitions are exactly the expected three.
- Fixed-field order/splitting does not affect encoding identity.
- Alias/binding order does not affect encoding identity.
- Operand order is part of interface identity.
- rv32/rv64 mixing is rejected.

---

## 10. Operation points

| Area | File |
| --- | --- |
| raw field bit layout | `binary-build/runtime/lib/riscv/raw/*.rkt` |
| logical operand grouping | `binary-build/layout/groups.rkt` |
| source syntax | `binary-build/parse.rkt` |
| import/pseudo policy | `binary-build/resolve.rkt` |
| raw/rebuilt operand planning | `binary-build/layout/plan.rkt` |
| instruction module codegen | `binary-build/emit/instruction.rkt` |
| metadata schema/codegen | `binary-build/runtime/lib/info/struct.rkt`, `binary-build/emit/metadata.rkt` |
| runtime signatures/query | `binary-build/runtime/lib/info/query.rkt` |
| runtime lookup | `binary-build/runtime/lib/info/lookup.rkt` |
| output layout | `binary-build/paths.rkt` |
| CLI options | `binary-build/config.rkt` |
| clean/copy/build phases | `binary-build/emit/package.rkt` |

---

## 11. Future work

Possible next steps, in priority order:

1. Generate raw field modules from a declarative table if the hand-written
   modules become too large.
2. Add an option to allow ambiguous same-priority definitions with warnings,
   for experimenting with future riscv-opcodes snapshots.
3. Support 48-bit encodings by widening `bit.rkt` and `parcel.rkt`.
4. Add a source snapshot/version lock for `riscv-opcodes`.
