# amd64 指令模型

> 本文记录 `insn.rkt` 的指令表示、编码分类、前缀/字符串指令和后续扩展方式。
> 跨层边界见 [`ARCHITECTURE.md`](ARCHITECTURE.md)，操作数写法见 [`SEXP.md`](SEXP.md)。

## 1. 原则

1. **一条真实 form 只对应一种编码类别**。
2. `instruction-size` 和 `encode-instruction` 必须走同一套编码逻辑。
3. 尺寸在 layout 前固定；layout 之后不再决定 imm8/imm32、disp8/disp32、short/near。
4. 操作数是事实：寄存器、内存宽度、立即数形状都显式写在 form 里。
5. 伪写法和旧写法在更前面的层消失，`insn.rkt` 只看到规范 form。

## 2. 当前结构

`amd64/insn.rkt` 是共享事实层，同时服务 layout 和 encode：

```text
form + operands
  -> instruction-size
  -> encode-instruction
```

表项：

```scheme
(struct insn-def (arity encode))
```

- `arity`：固定操作数个数；
- `arity = #f`：可变元数，例如 `imul` 的 1/2/3 操作数形式；
- `encode`：操作数列表 -> 字节列表。

`encode-instruction` 负责 arity 检查和字节化；`instruction-size` 通过同一编码器得到尺寸。

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
| SSE（计划） | `movss/addss/...` | 强制前缀 + XMM 寄存器 + b128 内存 |

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

当前只有 GPR：

```text
rax ... r15
eax ... r15d
ax ... r15w
al ... r15b
```

后续计划：

- `xmm0 ... xmm15`：SSE；
- `cr0/cr2/cr3/cr4`、`dr0...dr7`：PC 控制/调试寄存器；
- 每类寄存器在 `registers.rkt` 里带 `class` 事实，GPR 编码器拒绝 XMM/控制寄存器。

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
```

尚未实现：SSE/xmm、控制/调试寄存器、`lgdt/lidt/lldt/ltr`、`wrmsr/rdmsr`、
`swapgs`、`sysretq`、`iretq`、`jmpf`/`far`、16/32 位模式。

## 9. 扩展顺序

1. **SSE/xmm**：`registers.rkt` 加 XMM class，`insn.rkt` 加强制前缀 helper 和
   `movss/addss/subss/mulss/divss/minss/maxss/sqrtss/ucomiss/roundss`，
   再补 `movd/movq/movdqa/ldmxcsr/stmxcsr/xorps/xorpd/orps`。
2. **PC 控制面**：control/debug register class、`mov cr/dr`、`lgdt/lidt/lldt/ltr`、
   `wrmsr/rdmsr`、`swapgs`、`sysretq`、`iretq`、`jmpf`。
3. **模式**：16/32/64 模式支持只对 PC 启动有意义；Linux/NetBSD 用户态保持 64。

## 10. 测试

```sh
racket amd64/encode/test.rkt
```

每条新 form 至少覆盖：

- golden bytes；
- `instruction-size` 与字节数一致；
- 宽度/REX/ModR/SIB 边界；
- 符号内存 displacement 的 layout 尺寸；
- 前缀 + 内部指令的组合。
