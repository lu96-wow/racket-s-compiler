# amd64 后端

这是与 `riscv/riscv-compiler` 分离的 amd64 后端。目标是把 s-expression 程序/数据
经过固定流水线变成每段字节。

## 文档索引

| 文档 | 内容 |
| --- | --- |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 分层、依赖规则、不变量、错误模型 |
| [`SEXP.md`](SEXP.md) | 程序/数据/内存/控制转移的 s-expression 形式 |
| [`INSTRUCTIONS.md`](INSTRUCTIONS.md) | 指令类别、前缀、字符串指令、扩展顺序 |
| [`TARGET.md`](TARGET.md) | target 事实与填充策略 |
| [`REGISTERS.md`](REGISTERS.md) | 寄存器 class、编码事实 |
| [`PLAN.md`](PLAN.md) | 目标、阶段计划和进度 |
| [`loko-compat/DESIGN.md`](loko-compat/DESIGN.md) | Loko 旧汇编写法到核心 item 的纯变换 |
| `*/DESIGN.md` | 每层的职责、输入输出、边界 |

## 当前流水线

```text
rich data
  -> expand-data
  -> flatten
  -> expand-pseudo
  -> analyze
  -> dce
  -> relax          ; 内部反复驱动 layout
  -> bind-labels
  -> encode
```

`layout` 可以单独选择，默认流通过 `relax` 间接使用它。

Loko 兼容入口是另一条纯前端：

```text
loko-source (text/data)
  -> loko-compat
  -> program-items + data-items
  -> expand-pseudo -> analyze -> ...
```

它只做写法变换；`%section` / `%comm` / `%origin` / `%mode` / `%call` 属于
image 层，当前显式报问题。

## 目录

```text
amd64/
  sexp.rkt           共享 s-exp 形状 + 内存操作数
  item.rkt           程序/数据 item 共享形状
  insn.rkt           真实指令表 + instruction-size + encode-instruction
  registers.rkt      寄存器事实
  target.rkt         目标事实 + 填充
  loko-compat/       Loko 旧汇编写法 -> 核心 item
  expand-data/
  flatten/
  expand-pseudo/
  analyze/
  dce/
  layout/
  relax/
  bind-labels/
  encode/
  flow/
  test/
```

`sexp.rkt` / `item.rkt` / `insn.rkt` / `registers.rkt` / `target.rkt` 是共享事实，
不属于某一层的策略。

## 当前状态

已实现：

- Loko 汇编写法兼容层（`loko-compat`）
- rich 数据展开、module/flatten 名字解析
- 伪指令规范化：`jmp/jcc/call/li`、条件码别名
- amd64 控制流分析、DCE
- block-aware 布局：place/region/wildcard、data runs、fallthrough 检查
- 段起始对齐/重叠、代码数据混放、RIP-relative/绝对 disp32 范围检查
- 精确 `instruction-size`
- `jmp-short/jcc-short -> near` 只增 relax
- bind-labels：anchors -> symbols + 最终 value 宽度检查
- encode：bound-layout -> build 字节
- 符号内存 displacement（固定 disp32，encode 时解析）
- 整数 `li` -> `mov`，地址表达式 `li` -> RIP-relative `lea`
- 基本整数/控制流/内存指令编码
- 整数扩展：`imul` 1/2/3、shift by `cl`、`push/pop` 内存/立即数、`xchg/bswap/bsf/bsr/popcnt/shrd`
- 系统指令：`cdqe/cpuid/rdtsc/rdtscp/syscall/in/out/clc/stc/cli/sti/hlt/pushfq/popfq`
- 原子/缓存/屏障：`cmpxchg/xadd/rdrand/rdseed/clflush/mfence/lfence/sfence`
- 前缀和字符串指令：`(prefix lock …)`、`(prefix rep …)`、`movs/stos/ins/outs`
- SSE/XMM：`movss/movq/movd/movdqa`、算术/比较/转换、`ldmxcsr/stmxcsr`、`xorps/xorpd/orps`
- PC 控制面：`mov cr/dr`、`lgdt/lidt/lldt/ltr`、`rdmsr/wrmsr`、`swapgs/sysretq/iretq`
- `comment` 零尺寸 item、`cmovcc`、`b128` 内存宽度事实

未实现：

- `needs-far` / far form / trampoline / scratch 寄存器
- image 层：`%section` / `%comm` / `%origin` / `%mode` / `%call`
- 外部符号 / reloc / loader
- `adc/sbb`、AVX、更多双精度/packed SSE
- `jmpf`/`far`、16/32 位模式

## 测试

```sh
racket amd64/loko-compat/test.rkt
racket amd64/encode/test.rkt
racket amd64/expand-pseudo/test.rkt
racket amd64/expand-data/test.rkt
racket amd64/flatten/test.rkt
racket amd64/layout/test.rkt
racket amd64/analyze/test.rkt
racket amd64/relax/test.rkt
racket amd64/test/end-to-end.rkt
racket amd64/test/flow-test.rkt
```
