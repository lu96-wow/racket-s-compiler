# 当前缺口

> 项目已经按 `amd64-asm` / `compiler` / `amd64-help` / `loko-compatibility`
> 拆开。本文记录拆分后仍然缺的结构和能力。

## 1. 结构缺口

| 位置 | 现状 | 缺口 |
| --- | --- | --- |
| `loko-compatibility/` | `translate.rkt` + `lower/`：伪寄存器、liveness、图着色 | lower 还缺跨调用值 spill、frame allocation；符号乘法等表达式仍未接 |
| `loko-compatibility/` | 同上 | 没有 `image/`：`%origin` / `%section` / `%comm` / `%call`、BSS/NOBITS、strtab/symtab、ELF |
| `amd64-help/` | `li.rkt`、`ranges.rkt` | 还没有 far/trampoline、符号表达式、branch/远地址辅助 |
| `amd64-asm/` | 指令编码、寄存器、target | 没有通用 `bss` 段、far form、16/32 模式、外部 reloc/loader |
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

还缺：

- 跨调用值的 preserved 分配或 spill
- frame allocation / `LOCALS`
- `%comment liveness-information` -> GC 注记
- peephole
- 固定值表达式求值

### `loko-compatibility/image/`

- `%origin` -> segment start
- `%section` -> section metadata
- `%comm` -> BSS/NOBITS
- `%call` -> 声明式 strtab/symtab，替代宿主回调
- symbol metadata（start/end/section/misc）
- ELF header / segment table / section table / strtab / symtab

### `amd64-asm/` 通用能力

- `jmp-far` / `jcc-far` / `call-far`
- scratch / trampoline
- 通用 `bss` / NOBITS 段表示
- `%mode` 16/32/64 对应的编码模式
- `jmpf` + far pointer
- 外部符号 / reloc / loader（如果以后需要）

## 3. 表达式缺口

当前核心地址表达式只有：

```text
整数 | (链) | (+ …) | (- …)
```

还缺：

- 带标签的 `*` / `bitwise-xor` / `bitwise-not` 等其它表达式
- `%u128` 的符号表达式

## 4. 集成缺口

- Racket 后端与 R6RS Loko 之间的调用/序列化桥
- 使用真实 Loko codegen 输出做 golden test
- 统一 test runner

## 5. 建议顺序

1. `loko-compatibility/lower/`：先让优化后的真实寄存器代码进来
2. `amd64-asm/` 通用 `bss` + far form + mode
3. `loko-compatibility/image/`：BSS/ELF/symbol table
4. `amd64-help/`：far/表达式辅助
5. Racket ↔ Loko bridge
