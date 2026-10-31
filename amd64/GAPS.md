# 当前缺口

> 项目已经按 `amd64-asm` / `compiler` / `amd64-help` / `loko-compatibility`
> 拆开。本文记录拆分后仍然缺的结构和能力。

## 1. 结构缺口

| 位置 | 现状 | 缺口 |
| --- | --- | --- |
| `loko-compatibility/` | `translate.rkt` + `lower/`：符号元数据、sections/origin/mode、伪寄存器、liveness、图着色 | lower 还缺跨调用值 spill、frame allocation；image plan 尚未消费 sections |
| `loko-compatibility/` | 同上 | 没有 `image/`：sections/comms -> layout-spec、`%call`、BSS/NOBITS、strtab/symtab、ELF |
| `amd64-help/` | `li.rkt`、`ranges.rkt` | 还没有 far/trampoline、符号表达式、branch/远地址辅助 |
| `amd64-asm/` | 指令编码、寄存器、target、通用 `reserve`/bss 段 | 还缺 far form、16/32 模式、外部 reloc/loader |
| `compiler/` | 纯 S-expression 编译流水线 | 没有 image writer；这是有意的，image 不属于编译器 |
| 仓库根 | 分层测试脚本 | 还没有一个统一 test runner |

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

还缺：

- 跨调用值的 preserved 分配或 spill
- frame allocation / `LOCALS`
- `%comment liveness-information` -> GC 注记
- peephole
- 固定值表达式求值

### `loko-compatibility/image/`

已完成：

- `layout-spec.rkt`：`loko-ir` 的 sections/origin/modes/comms -> 带 bss segment 的
  粗布局 `layout-spec`
- [`amd64-elf/writer.rkt`](../amd64-elf/writer.rkt)：build + symbols -> 静态 ELF64（单 PT_LOAD、NOBITS BSS、symtab/strtab）
- section 起始 synthetic label、place 规则、空 section、data section 边界
- code section 非 64 位 -> `mode-unsupported`

还缺：

- 精确尺寸（当前用 near 分支上界，DCE 后可能留 gap）
- `%call` -> 声明式 ELF header / strtab/symtab，替代宿主回调
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
- `kind bss` 段；encode 不生成文件字节
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
- 统一 test runner

## 5. 建议顺序

1. `loko-compatibility/translate.rkt`：`%label start end` 语义、sections/origin/mode 采集已完成
2. `loko-compatibility/lower/`：补齐 spill / frame / GC 注记
3. `loko-compatibility/image/`：loko-ir -> layout-spec、call、BSS/NOBITS、ELF/symtab
4. `amd64-asm/` far form + mode
5. `amd64-help/`：far/表达式辅助
6. Racket ↔ Loko bridge
