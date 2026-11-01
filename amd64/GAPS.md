# 当前缺口

> 项目已经按 `amd64-asm` / `compiler` / `amd64-help` / `amd64-elf` /
> `loko-compatibility` 拆开。本文记录拆分后仍然缺的结构和能力。

## 1. 结构缺口

| 位置 | 现状 | 缺口 |
| --- | --- | --- |
| `loko-compatibility/` | `translate.rkt` + `lower/` + `image/layout-spec.rkt`：符号元数据、sections/origin/mode、伪寄存器、liveness、图着色、自动 layout-spec | lower 还缺跨调用值 spill、frame allocation、GC 注记；`%call` 还没有声明式替代 |
| `amd64-elf/` | build + symbols + image-plan -> 静态 ELF64 | 单 PT_LOAD 默认、plan 可多 PT_LOAD；还缺精确 symbol metadata / reloc |
| `amd64-help/` | `li.rkt`、`ranges.rkt` | 还没有 far/trampoline、符号表达式、branch/远地址辅助 |
| `amd64-asm/` | 指令编码、寄存器、target、NASM 生成表、通用 `reserve`/hole 段 | 还缺 x87/MMX、AVX/VEX、far form、16/32 模式、外部 reloc/loader |
| `compiler/` | 纯 S-expression 编译流水线 | 没有 image writer；这是有意的，image 不属于编译器 |
| 仓库根 | `run-tests.sh` + `tools/` | Loko dump/cache 依赖外部 Loko 仓库，已在 `tools/` 提供 patch 和步骤 |
| `compiler/flow/` | core stage 引擎 + 兼容入口 | Loko/ELF 已移到 `loko-compatibility/flow.rkt`；核心 flow 不再 require 可选层 |
| `amd64-help/` | `li` / `ranges` / `cc` / `branch` / `main` | 还缺 `la` / `jump` / `scratch` 和 far/trampoline 策略 |
| `amd64-asm/special/*.rkt` | 全部手写 special 已产出 `encoding-plan` | 下一步是 target/mode 参数化和 far/trampoline |
| `amd64-asm/sexp.rkt` | 兼容 facade | 新代码应直接用 `shape.rkt` / `memory.rkt`；target mode 已加入 |

## 2. Loko 编译链缺口

要真正编译 Loko，至少还需要：

### `loko-compatibility/lower/`

已完成：

- 伪寄存器 `(reg N)` 消除（`pseudo.rkt`）
- uses/sets 与基本块 liveness（`uses.rkt` / `liveness.rkt`）
- 干涉图 + 图着色分配（`allocate.rkt`）
- 组合入口与未分配/未着色报告（`lower.rkt`）
- 调用点 save/restore 注记展开（`calls.rkt`）
- `lower/ir.rkt`：`loko-ir` code section 的 lower，已接入 flow
- `%init-bss` 的 64 位显式展开（`translate.rkt`）

说明：Loko 实际导出的是 `pass-optimize` 之后的代码，真正的指令已经没有
`(reg N)`；剩余的伪寄存器只在注释里。因此 Loko 验证路径不需要再分配。
原始 codegen 输入仍缺：

- 跨调用值的 preserved 分配或 spill
- frame allocation / `LOCALS`
- `%comment liveness-information` -> GC 注记
- peephole
- 固定值表达式求值

### `loko-compatibility/image/`

已完成：

- `layout-spec.rkt`：`loko-ir` 的 sections/origin/modes/comms -> 带 hole segment 的
  粗布局 `layout-spec`
- [`amd64-elf/writer.rkt`](../amd64-elf/writer.rkt)：build + symbols + image-plan -> 静态 ELF64（默认单 PT_LOAD，plan 可多 PT_LOAD；NOBITS BSS、symtab/strtab）
- section 起始 synthetic label、place 规则、空 section、data section 边界
- code section 非 64 位 -> `mode-unsupported`

还缺：

- ~~精确尺寸~~：地址现在由 `compiler/layout` 求解，near 上界只用于容量校验，
  gap 不再影响后续段起点
- ~~`%call` 通用替代~~：dump 改成标 `(%elf-header)` / `(%elf-tail)`，`loko-compat`
  丢掉这两段（`strip-elf-wrapper`），`%call` 不再出现在编译器输入里
  的 plan-only reserved region 替代 ELF header/footer
- `%elf` / `image-plan` 已支持 canonical region/load/symbol；`content`/`perm` 派生 ELF 元数据；还需要覆盖 Loko 现有 ELF callback 的全部语义
- 消费 `translate.rkt` 已采集的 symbol metadata（start/end/section/misc）
- 多 PT_LOAD / text-data 权限分离
- 符号 size（当前为 0）
- reloc / dynamic linking

### `amd64-asm/` 通用能力

- `jmp-far` / `jcc-far` / `call-far`
- scratch / trampoline
- `%mode` 16/32/64 对应的编码模式
- `jmpf` + far pointer
- 外部符号 / reloc / loader（如果以后需要）

已完成：

- 通用 `(reserve n)` item
- `kind hole` 段（有位置、没有文件字节）；encode 不生成文件字节
- `cld` 编码

## 3. 表达式缺口

当前核心地址表达式只有：

```text
整数 | $ | (链)
| (+ …) | (- …)
| (bitwise-and …) | (bitwise-ior …)
| (ash a n) | (bitwise-bit-field n start end)
```

还缺：

- 带标签的 `*` / `bitwise-xor` / `bitwise-not` 等其它表达式
- `%u128` 的符号表达式

## 4. 集成缺口

- Racket 后端与 R6RS Loko 之间的调用/序列化桥
- 使用真实 Loko codegen 输出做 golden test
- 统一 test runner（已完成：`run-tests.sh`）

## 5. 建议顺序

1. `loko-compatibility/translate.rkt`：`%label start end` 语义、sections/origin/mode 采集已完成
2. `loko-compatibility/lower/`：补齐 spill / frame / GC 注记
3. `loko-compatibility/image/`：`%call` 的声明式 ELF 计划；`layout-spec` 已自动生成
4. `amd64-asm/` far form + mode
5. `amd64-help/`：far/表达式辅助
6. Racket ↔ Loko bridge
