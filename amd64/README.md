# amd64 后端

amd64 后端拆成五个子项目：

```text
amd64/
  amd64-asm/           二进制编码：寄存器、target、指令编码
  compiler/            S-expression 汇编编译器：展开、分析、布局、编码
  amd64-help/          x64 辅助函数：li 展开、范围判断
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
  -> relax          ; 内部反复驱动 layout
  -> bind-labels
  -> encode
```

Loko 兼容入口：

```text
loko-source
  -> loko-compat -> loko-ir
  -> loko-lower
  -> loko-image -> program-items/data-items/layout-spec
  -> compiler 的后半段
  -> build -> amd64-elf
```

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

`li` 展开和整数范围判断等辅助函数；不编码、不布局。

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
| [`SEXP.md`](SEXP.md) | 程序/数据/内存/控制转移的 s-expression 形式 |
| [`PLAN.md`](PLAN.md) | 目标和进度 |
| [`GAPS.md`](GAPS.md) | 拆分后仍缺的结构和能力 |
| `*/DESIGN.md` | 每层职责、输入输出、边界 |

## 当前状态

已实现：

- 指令编码：整数/控制流/内存/系统/SSE/PC 控制面
- `prefix` 与字符串指令
- block-aware 布局、place/region/wildcard、fallthrough 检查
- short -> near relax
- bind-labels + value 宽度检查
- encode 最终尺寸断言
- Loko 旧汇编写法兼容层（`$`、符号位运算）
- lower 第一版：伪寄存器、liveness、图着色分配、调用点 save/restore 展开
  （不含 spill/frame allocation）；`loko-lower` 已接入 flow
- 通用 `reserve` / `kind bss` 段；BSS 不生成文件字节
- Loko `%init-bss` 的 64 位显式展开（opt-in）
- Loko `%comm` 收集与 bss section 展开
- `loko-ir` -> 自动 `layout-spec`（sections/origin/bss，粗布局上界）
- `build` + symbols -> 静态 ELF64（单 PT_LOAD、NOBITS BSS、symtab/strtab）

未实现：

- lower 的跨调用值 spill、frame allocation
- `needs-far` / far form / trampoline / scratch 寄存器
- image 层：`%call`、多 PT_LOAD / 权限分离、reloc/dynamic linking
- 外部符号 / loader
- `jmpf`/`far`、16/32 位模式
- `adc/sbb`、AVX、更多双精度/packed SSE

## 测试

```sh
racket amd64/amd64-asm/test.rkt
racket amd64/compiler/expand-data/test.rkt
racket amd64/compiler/flatten/test.rkt
racket amd64/compiler/expand-pseudo/test.rkt
racket amd64/compiler/analyze/test.rkt
racket amd64/compiler/layout/test.rkt
racket amd64/compiler/relax/test.rkt
racket amd64/compiler/test/end-to-end.rkt
racket amd64/compiler/test/flow-test.rkt
racket amd64/loko-compatibility/test.rkt
racket amd64/loko-compatibility/image/test.rkt
racket amd64/amd64-elf/test.rkt
racket amd64/loko-compatibility/lower/test.rkt
```
