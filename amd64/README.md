# amd64 后端

amd64 后端拆成五个子项目：

```text
amd64/
  amd64-asm/           二进制编码：寄存器、target、指令编码
  compiler/            S-expression 汇编编译器：展开、分析、布局、编码
  amd64-help/          x64 辅助函数：li 展开、指令长度、范围判断
  amd64-elf/           build + symbols -> ELF64 image
  loko-compatibility/  Loko 旧汇编写法 -> 核心 item / loko-ir
```

整体流水线：

```text
rich data
  -> expand-data
  -> flatten
  -> expand-pseudo
  -> analyze
  -> dce
  -> layout
  -> bind-labels
  -> encode
```

Loko 兼容入口（可选扩展，不属于 core flow）：

```text
loko-source
  -> loko-compat -> loko-ir
  -> loko-lower
  -> loko-image -> program-items/data-items/layout-spec
  -> compiler 的后半段
  -> build -> amd64-elf
```

核心 flow 在 `compiler/flow/core.rkt`；`loko-compatibility/flow.rkt` 只负责
把可选阶段注册到同一个 stage 引擎。

## 子项目

### `amd64-asm`

只负责单条真实指令的尺寸和字节，以及寄存器/target 事实。

| 文件 | 内容 |
| --- | --- |
| [`amd64-asm/README.md`](amd64-asm/README.md) | 子项目入口 |
| [`amd64-asm/INSTRUCTIONS.md`](amd64-asm/INSTRUCTIONS.md) | 指令类别、前缀、字符串指令 |
| [`amd64-asm/REGISTERS.md`](amd64-asm/REGISTERS.md) | 寄存器 class、编码事实 |
| [`amd64-asm/TARGET.md`](amd64-asm/TARGET.md) | target 与填充策略 |

### `compiler`

S-expression 汇编编译器，负责 item、控制流、布局、松弛、绑定和 build。

| 文档 | 内容 |
| --- | --- |
| [`compiler/README.md`](compiler/README.md) | 流水线、层目录、测试 |
| `compiler/*/DESIGN.md` | 每层的作用、相关 s-exp、设计思路、边界 |

### `amd64-help`

`li` 展开、指令长度统一入口和整数范围判断等辅助函数；不编码、不布局。

### `amd64-elf`

把 `build` + symbols 写成静态 ELF64；不依赖 Loko 前端。

| 文件 | 内容 |
| --- | --- |
| [`amd64-elf/writer.rkt`](amd64-elf/writer.rkt) | ELF header、program/section headers、symtab/strtab |
| [`amd64-elf/DESIGN.md`](amd64-elf/DESIGN.md) | 输入输出、布局、边界 |

### `loko-compatibility`

Loko 旧汇编写法到核心 item + `loko-ir` 的纯变换；不生成最终 image/ELF。

## 总文档

| 文档 | 内容 |
| --- | --- |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 跨项目分层、依赖规则、错误模型 |
| [`SYNTAX.md`](SYNTAX.md) | 用户表面语法：程序/数据/内存/控制转移 |
| [`IR.md`](IR.md) | 层间 IR、owner、阶段输入输出和局部性规则 |
| [`ROADMAP.md`](ROADMAP.md) | 路线图与进度 |
| [`GAPS.md`](GAPS.md) | 已知缺口 |
| `*/DESIGN.md` | 每层职责、输入输出、边界 |

## 当前状态

已实现：

- 指令编码：整数/控制流/内存/系统/SSE/PC 控制面
- NASM `insns.dat` 驱动的指令表生成（`insn-generic.rkt` + `generated/`）
- `prefix` 与字符串指令
- block-aware 布局、place/region/wildcard、fallthrough 检查
- 显式 short/near 分支形式（后端不做松弛）
- bind-labels + value 宽度检查
- encode 最终尺寸断言
- Loko 旧汇编写法兼容层（`$`、符号位运算）
- lower 第一版：伪寄存器、liveness、图着色分配、调用点 save/restore 展开
  （不含 spill/frame allocation）；`loko-lower` 已接入 flow
- 通用 `reserve` / `kind hole` 段（有位置、没有文件字节）
- Loko `%init-bss` 的 64 位显式展开（opt-in）
- Loko `%comm` 收集与 bss section 展开
- `loko-ir` -> 自动 `layout-spec`（sections/origin/hole，粗布局上界）
- `build` + symbols -> 静态 ELF64（默认单 PT_LOAD，plan 可多 PT_LOAD；NOBITS BSS、symtab/strtab）
- `%elf` / `image-plan`：canonical region/load/symbol；content/perm 派生 ELF 元数据

已实现：Loko Linux 默认 `%elf` 计划（text/data/bss/stack0/heap0，多 PT_LOAD、
plan-only reserved region）、near-only 默认流、Loko 输出缓存工具。

未实现：

- 原始 codegen 输出的完整 lower：跨调用 spill、frame allocation；当前 Loko
  验证路径使用 Loko `pass-optimize` 之后的已分配代码
- `%call` 的通用声明式替代（Loko Linux 路径用 `image/plan.rkt`）
- far form / trampoline / scratch 寄存器
- 外部符号 / loader、reloc/dynamic linking
- `jmpf`/`far`、16/32 位模式
- x87/MMX、AVX/VEX/EVEX、far form、16/32 位模式

## 测试

先 `raco make` 再跑，避免每次展开模块：

```sh
cd amd64
./run-tests.sh
```

单独跑某个测试：

```sh
racket amd64/amd64-asm/test.rkt
racket amd64/compiler/test/end-to-end.rkt
```

`amd64-asm/test-oracle.rkt` 用 LLVM MC 作为独立编码 oracle：同一批 form
分别由本后端和 `llvm-mc` 编码，逐字节比较。没有 `llvm-mc` 时自动跳过。
新增指令时先加 oracle case，再加手算 golden test。

## Loko 验证：dump -> 流水线 -> 镜像

完整 `analyze -> dce -> layout -> encode` 对 Loko 运行时约 24 s（pc-repl 的
裸机镜像 1.6M 个 item）。验证编码/镜像时不要每次重跑：

```sh
# 1. 从 Loko 仓库导出程序（Loko 树里装了 sexp target，见 tools/README.md 第 1 节）
LOKO_PROGRAM_SEXP=/tmp/prog.sexp ./loko-prebuilt -ftarget=sexp \
    --compile program.sps --output /tmp/prog.bin

# 2. 流水线 + 产物缓存（dump 没变时 1.7 s；`--verify` 会重跑核对）
racket tools/loko-flow.rkt /tmp/prog.sexp /tmp/cache elf

# 3. 之后改 encoder/ELF/落盘，只需从缓存取出字节
racket tools/write-cached-elf.rkt /tmp/cache/loko-elf.rktd /tmp/prog.elf
```

缓存的是**这次流水的产物**（`encode` 的 `build`，或 `loko-elf` 的 `image`），
不是中间层——逐层缓存在 pc-repl 上要写 443 MB、命中 189 s，比全量重算还慢。
dump 解析也不再走 `read`：`loko-compatibility/sexp-read.rkt` 直接扫字节
（44 MB：12 s -> 2.4 s，结果与 `read` 逐 item 相等）。

默认流是 near-only：`jmp` / `jcc` 展开成 near，short 只能由前端显式写
`jmp-short` / `jcc-short`。`loko-near` 保留为历史别名，和 `loko` 等价。
