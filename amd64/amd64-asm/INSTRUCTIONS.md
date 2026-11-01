# amd64 指令模型

> 本文记录 `insn.rkt` 的指令表示、编码分类、前缀/字符串指令和后续扩展方式。
> 跨层边界见 [`ARCHITECTURE.md`](../ARCHITECTURE.md)，操作数写法见 [`../SEXP.md`](../SEXP.md)。

## 1. 原则

1. **一条真实 form 只对应一种编码类别**。
2. `instruction-size` 和 `encode-instruction` 必须走同一套编码逻辑。
3. 尺寸在 layout 前固定；layout 之后不再决定 imm8/imm32、disp8/disp32、short/near。
4. 操作数是事实：寄存器、内存宽度、立即数形状都显式写在 form 里。
5. 伪写法和旧写法在更前面的层消失，`insn.rkt` 只看到规范 form。

## 2. 当前结构

`amd64-asm/insn.rkt` 是共享事实层，同时服务 layout 和 encode：

```text
form + operands
  -> instruction-size
  -> encode-instruction
```

现在有两条编码路径，但尺寸和字节仍共用同一入口：

1. **手写特殊 form**（`insn.rkt`）：控制转移、`prefix`、字符串指令、
   `mov` 的立即数选择、`jcc/setcc/cmovcc` 条件码伪 form，以及少量
   需要特殊寄存器模型的指令。
2. **NASM 生成表**（`insn-generic.rkt` + `generated/gen/insn/nasm.rkt`）：
   其余 legacy x86 / SSE / SSE2 form。数据由 `binary-build/` 从 NASM
   `x86/insns.dat` 的预处理快照生成；来源和刷新方式见
   [`NASM.md`](NASM.md)。

手写表项：

```scheme
(struct insn-def (arity encode))
```

- `arity`：固定操作数个数；
- `arity = #f`：可变元数，例如 `imul` 的 1/2/3 操作数形式；
- `encode`：操作数列表 -> 字节列表。

生成表项：

```scheme
(mnemonic operands encoding flags source-line)
```

生成表路径在运行时也分成策略/约束和字节生成两段：

```text
operands
  -> generic-plan-instruction   约束检查 + 选 form + 固定 prefix/REX/imm
  -> instruction-plan           已确定的 plan（长度由 plan-size 得到）
  -> encode-plan                只拼接字节，不再做选择
```

`generic-instruction-size` 直接从 plan 得到尺寸，layout 不需要先编码；
`generic-encode-instruction` 等价于 `(encode-plan (generic-plan-instruction ...))`。
`insn-core.rkt` 统一提供 ModR/M、SIB、REX、displacement 和立即数范围。
`plan.rkt` 把手写 special 和生成表统一成 `resolved-plan`：

```text
instruction-plan -> plan-size / encode-plan
```

`encode-instruction` 先查手写 form，再回退到生成表；`instruction-size`
对两类 form 都经过 `instruction-plan` 得到 plan size。当前 special 仍以
“plan 阶段产出 bytes”为过渡实现，后续会继续改成真正的 form plan。

## 3. 编码类别

| 类别 | 例子 | 编码要点 |
| --- | --- | --- |
| 固定字节 | `cdqe cpuid rdtsc syscall clc` | 无操作数，固定 opcode |
| `r/m, reg` | `mov add xchg cmpxchg xadd` | ModR/M 的 reg 字段来自寄存器操作数 |
| `reg, r/m` | `mov` load、`lea`、`bsf/bsr/popcnt` | ModR/M 的 r/m 字段来自源操作数 |
| `/digit` | `inc dec neg not div idiv` | ModR/M.reg 是 opcode 扩展 |
| 移位 | `shl/shr/sar` | 立即数用 `C0/C1`，`cl` 用 `D2/D3` |
| `imul` | 1/2/3 操作数 | `F6/F7 /5`、`0F AF`、`6B/69` |
| `push/pop` | 寄存器、内存、立即数 | 64 位内存形式使用默认 64 位操作数，不额外发 REX.W |
| 端口 I/O | `in/out` | `AL/AX/EAX` + `DX` 或 imm8 |
| 字符串 | `movs/stos/ins/outs` | 隐式 `rSI/rDI/DX`，操作数只用于选宽度 |
| 前缀 | `(prefix lock ...)` / `(prefix rep ...)` | 一个 legacy prefix 字节 + 内部指令 |
| 系统 | fences、`clflush`、`rdrand/rdseed` | 固定 opcode 或 `/digit` |
| SSE | `movss/addss/...` | 强制前缀 + XMM 寄存器 + b128 内存 |

## 4. 前缀表示

前缀是显式 form，不是助记符的一部分：

```scheme
(prefix lock (xadd (b64 (base rax)) rbx))
(prefix rep  (movs (b64 (base rdi)) (b64 (base rsi))))
```

编码：

```text
legacy prefix byte
  + 内部指令的完整编码
```

- `lock` -> `F0`
- `rep` / `repz` -> `F3`
- `repne` / `repnz` -> `F2`

尺寸也递归：

```text
size(prefix p inner) = 1 + size(inner)
```

这样 `layout` 不需要认识字符串指令或前缀细节。

## 5. 字符串指令

字符串指令的地址是隐式的，操作数只表达宽度：

```scheme
(movs (b64 (base rdi) (disp 0)) (b64 (base rsi) (disp 0)))
(stos (b64 (base rdi) (disp 0)) rax)
(ins  (b32 (base rdi) (disp 0)) dx)
(outs dx (b32 (base rsi) (disp 0)))
```

编码只看宽度：

| form | 8 | 16 | 32 | 64 |
| --- | --- | --- | --- | --- |
| `movs` | `A4` | `66 A5` | `A5` | `48 A5` |
| `stos` | `AA` | `66 AB` | `AB` | `48 AB` |
| `ins` | `6C` | `66 6D` | `6D` | 不支持 |
| `outs` | `6E` | `66 6F` | `6F` | 不支持 |

`ins` / `outs` 没有 64 位形式；Loko 的 `mem+` 在 64 位模式下按 32 位处理。

## 6. 立即数选择

- ALU 立即数：`imm8` 能放下就用 `83 /digit ib`，否则用 `81 /digit iz`。
- `imul` 三操作数：`imm8` 能放下就用 `6B`，否则用 `69`。
- `push` 立即数：`imm8` 能放下就用 `6A`，否则用 `68 id`。
- 分支 short/near 由 `jmp-short/jmp-near` 的 **form** 决定，不由编码器临时选择。
- 符号立即数目前只支持分支目标和数据 `value` 表达式；普通指令立即数要求整数。
  未来如果要把标签当立即数，必须先在布局前固定宽度。

## 7. 寄存器类

当前寄存器类：

```text
GPR:      rax ... r15 / eax ... r15d / ax ... r15w / al ... r15b
XMM:      xmm0 ... xmm15
control:  cr0 cr2 cr3 cr4 cr8
debug:    dr0 ... dr7
```

`registers.rkt` 的 `reg` 带 `class` 事实（`'gpr` / `'xmm` / `'control` / `'debug`）。
GPR 编码器通过 `parse-reg` / `parse-rm` 拒绝 XMM/控制/调试寄存器；
SSE 编码器通过 `parse-xmm` / `parse-xmm-or-mem` 接受 XMM；
`mov cr/dr` 在 `encode-mov` 里走专门的控制/调试寄存器编码。

后续计划：

- 模式相关的 16/32 位寄存器形式。

## 8. 当前已实现

```text
mov add sub and or xor cmp test lea
push pop
inc dec neg not
shl shr sar
imul（1/2/3 操作数）
div idiv
movzx movsx
setcc cmovcc
cqo cdq cdqe
xchg
bswap
bsf bsr popcnt shrd
cmpxchg xadd
rdrand rdseed
cpuid rdtsc rdtscp
syscall
in out
clc stc cli sti hlt pause
pushfq popfq
clflush mfence lfence sfence
movs stos ins outs
prefix lock / rep

movss movq movd movdqa
addss subss mulss divss minss maxss sqrtss
ucomiss roundss
cvtss2sd cvtsd2ss cvtsi2ss
ldmxcsr stmxcsr
xorps xorpd orps

mov cr/dr
lgdt lidt lldt ltr
rdmsr wrmsr
swapgs sysretq iretq
```

生成表已经补齐的常见家族：

```text
adc sbb
shld shrd
bt bts btr btc bsf bsr lzcnt tzcnt popcnt
movbe crc32 cmpxchg8b cmpxchg16b
SSE/SSE2 legacy forms（addsd/addps/movapd/pxor/paddq/movdqu/...）
xgetbv clts rdpkru stac 等 fixed-opcode 系统指令
```

尚未实现：x87/MMX、AVX/VEX/EVEX/APX、`jmpf`/`far`、16/32 位模式。

## 9. 内存/REX 不变量

- `REX.B` 只由 **base** 决定；`REX.X` 只由 **index** 决定。
  不要把 index 的扩展位 OR 进 `REX.B`，否则 `[rsp+r10]` 会变成 `[r12+r10]`。
- `rsp` 不能作 index；`r12` 可以，编码为 SIB index=4 且 `REX.X=1`。
- 8 位内存 load/store 必须用 `8A /r` / `88 /r`；用 `8B/89` 会把
  `dl` 静默解释成 `edx`，写入 4 字节。
- 符号立即数在 layout 时固定成 imm32/imm64，encode 只填入值；
  不能在 layout 后根据最终值改宽度。

## 10. 扩展顺序

新增真实指令时：

1. 先查 `nasm/insns.pre.dat`，确认 NASM 已有对应 row；
2. 刷新/运行 `binary-build/main.rkt`，让 `generated/gen/insn/nasm.rkt`
   包含该 form；
3. 在 `test-generated.rkt` 加 golden bytes，在 `test-oracle.rkt` 加 LLVM
   MC 对照；
4. 只有公共拼写与 NASM row 不是一一对应时（`jmp-short`、`jcc`、
   `setcc`、`prefix`、`mov` 立即数策略），才在 `insn.rkt` 写特殊 form。

后续大块能力：

1. **PC 模式/远跳**：`%mode` 16/32/64、`jmpf` + `(far seg offset)`。
2. **SSE 扩展**：按需补 `movsd/addsd/...` 等双精度和更多 packed 指令。

## 11. 测试

```sh
cd amd64 && ./run-tests.sh
# 或
racket amd64-asm/test.rkt
```

`test-oracle.rkt` 用 `llvm-mc -show-encoding` 做独立编码 oracle；新增 form
时先加 oracle case，再加 golden bytes。

每条新 form 至少覆盖：

- golden bytes；
- `instruction-size` 与字节数一致；
- 宽度/REX/ModR/SIB 边界；
- 符号内存 displacement 的 layout 尺寸；
- 前缀 + 内部指令的组合。
