# 当前缺口

> 项目已经按 `amd64-asm` / `compiler` / `amd64-help` / `loko-compatibility`
> 拆开。本文记录拆分后仍然缺的结构和能力。

## 1. 结构缺口

| 位置 | 现状 | 缺口 |
| --- | --- | --- |
| `loko-compatibility/` | 只有 `translate.rkt`：旧写法 -> 核心 item | 没有 `lower/`：伪寄存器、regalloc、liveness、`%comment` 解释、`$` / 符号位表达式 |
| `loko-compatibility/` | 同上 | 没有 `image/`：`%origin` / `%section` / `%comm` / `%call`、BSS/NOBITS、strtab/symtab、ELF |
| `amd64-help/` | `li.rkt`、`ranges.rkt` | 还没有 far/trampoline、符号表达式、branch/远地址辅助 |
| `amd64-asm/` | 指令编码、寄存器、target | 没有通用 `bss` 段、far form、16/32 模式、外部 reloc/loader |
| `compiler/` | 纯 S-expression 编译流水线 | 没有 image writer；这是有意的，image 不属于编译器 |
| 仓库根 | 分层测试脚本 | 还没有一个统一 test runner |

## 2. Loko 编译链缺口

要真正编译 Loko，至少还需要：

### `loko-compatibility/lower/`

- 伪寄存器 `(reg N)` 消除
- register allocation / spill
- liveness
- `%comment liveness-information` -> GC 注记
- peephole
- `%equiv` / `%label name end` / `%u*` / `%vu8` / `%utf8z`
- `$` 当前 IP
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

- 带标签的 `bitwise-ior` / `bitwise-and` / `ash` / `bitwise-bit-field`
- `$` 当前地址
- `%u128` 的符号表达式
- bind 之后的符号表达式求值层

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
