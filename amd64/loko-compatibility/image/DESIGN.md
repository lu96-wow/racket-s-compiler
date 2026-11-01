# loko-image

> 目录：`amd64/loko-compatibility/image/`
>
> Loko 前端策略里的“布局/镜像准备”层。输入是 `loko-ir`，输出是 compiler
> 能直接消费的通用 s-expression。

## 1. 当前模块

```text
layout-spec.rkt   loko-ir -> layout-spec + program-items + data-items
plan.rkt          Loko Linux 的 %elf 计划（text/data/bss/stack0/heap0）
```

后续计划：

```text
call.rkt          %call -> declarative items / image plan
```

## 2. `layout-spec.rkt`

输入：

```scheme
(loko-ir
  (origin #x200000)
  (symbols ...)
  (comms ...)
  (sections (section ...) ...))
```

输出：

```scheme
layout-spec
program-items
data-items
problems
```

### 设计

- 以 `origin` 为起点，按 `sections` 源顺序累加地址。
- code section 用**near 分支**测量，得到安全上界；真正 short/near 选择仍由
  compiler 的 `expand-pseudo` + `relax` 完成。
- 每个 section 如果开头不是 label，就补一个内部 label：
  `loko-image-start-<section>`。
- 每个 section 生成一个 segment：
  `(segment (name ...) (kind code|data|hole) (start ...) (end ...) (align 1))`。
- 该 section 的所有 label 生成一条 `place`。
- 空 section 允许 `start == end`。
- data/bss section 之间插入零尺寸 `(comment section-boundary ...)`，避免相邻
  section 的 label 被 `<data-items>` 误合并成一个 data unit。
- code section 不是 64 位时产生 `mode-unsupported` problem。

### 边界

- 不做 DCE；因此 code section 的尺寸是保守上界，后续段起点可能留 gap。
- 不做 short/near 精确收缩；放松只会让实际尺寸变小，不会导致 overflow。
- 不生成 ELF；只生成 compiler 的 `layout-spec` 和扁平 items。
- `loko-ir` 的 `image-plan` 不在这里消费；它直接交给 `amd64-elf`。
- 不处理 `%call`；它仍是 `loko-compat` 的 problem。
- 多个 code section 的边界目前依赖前一个 section 以 terminator 结束；
  还没有通用的 `boundary` item 来强制切断 CFG。

## 3. `plan.rkt`

Loko 的 Linux 镜像不只需要 text/data/bss，还需要两个固定地址的 reserved 区：

```text
stack0   1 TiB + 4 KiB，大小 2 MiB - 4 KiB（第一页是 guard page）
heap0    1 TiB + 2 MiB，大小 16 MiB
```

这些地址来自 `loko/arch/amd64/memory.sls`，不是程序字节，所以：

- `layout-spec` 只负责 text/data/bss；
- `plan.rkt` 生成 `%elf` region/load 子句，`stack0`/`heap0` 是 plan-only
  reserved region，`amd64-elf` 直接生成 NOBITS + 零 filesz 的 PT_LOAD；
- 声明了 `%elf` 时优先使用声明；否则只在符号表里有 `(elf-entry)` 时使用
  Loko Linux 默认计划；两者都没有时退回单 `PT_LOAD`。

因此 `%call` 不再是 Linux 路径的必需项：ELF header/footer 由
`amd64-elf` 根据 build + plan 生成，不再执行 Loko 的宿主回调。

## 4. ELF

ELF writer 已独立到 [`../../amd64-elf/`](../../amd64-elf/DESIGN.md)。
本层只负责生成 `build` 之前的布局和扁平 items，以及 Loko 的 `%elf` 计划。

## 5. 测试

```sh
racket amd64/loko-compatibility/image/test.rkt
racket amd64/amd64-elf/test.rkt
```
