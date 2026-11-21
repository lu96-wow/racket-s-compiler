# 控制流：block、term、边

## 1. 核心原则

> 核心 IR 只有**边**，没有 `j` / `b` / `label`。

`(term (jump b1))` 不是 `j` 指令，`(term (branch cond b1 b2))` 不是 `beq`。
它们只表达“这个 block 的后继是谁”。布局层才决定这条边怎么变成字节：

- fallthrough；
- 条件分支；
- 无条件跳转；
- 远跳 / trampoline。

因此核心 IR 里不存在隐式 fallthrough。每个 block 都必须有且只有一个
terminator。

例外：`asm.code` 和 `raw` 是 machine 层，可以出现 `label` / `j` / `b`；
它们不是核心 IR 的边，也不能被当成函数内 block 的后继。

## 2. 形状

```scheme
(block b0
  op ...
  (term ...))
```

终止形式：

```scheme
(term (jump b1))
(term (branch cond b1 b2))
(term (return operand ...))
(term (trap))
```

- `(jump b1)`：一条边。
- `(branch cond b1 b2)`：两条边；`b1` 为真，`b2` 为假。
- `(return ...)` / `(trap)`：没有局部后继。

block 名是**函数局部 symbol**，例如 `b0`、`loop`、`exit`。不是全局链，
不参与名字解析，不进 link 表。

## 3. CFG

一个函数就是：

```scheme
(func (main)
  (vregs ...)
  (entry b0)
  (block b0 ...)
  (block b1 ...)
  ...)
```

CFG 由 `entry` + 每个 block 的 term 直接给出。不需要从 `label` / `branch`
反推，也不需要 `analyze`。

验证规则：

- `entry` 存在，且是函数内 block。
- 每个 block 的后继都在同一个函数内。
- 每个 block 恰好一个 term，且位于最后。
- 不存在跨函数边。
- 没有重复 block 名。
- `return` / `trap` 没有后继。

## 4. 布局如何物化边

布局层知道：

- block 的物理顺序；
- 每条 op 的最终尺寸；
- block 的地址；
- 目标是否在短跳范围内。

然后逐条边决定：

### `(term (jump b))`

- `b` 是物理下一块：不发射任何指令，直接落下去。
- `b` 不是物理下一块：发射无条件跳转（`j` / `jal x0` / 远形式）。

### `(term (branch cond b1 b2))`

- `b1` 是物理下一块：
  - 发射反向条件分支到 `b2`，然后落到 `b1`。
- `b2` 是物理下一块：
  - 发射正向条件分支到 `b1`，然后落到 `b2`。
- 两个都不是物理下一块：
  - 条件分支到其中一个，再无条件跳到另一个；
  - 或者条件跳转 + fallthrough 到一个新插入的 trampoline。
- 目标太远：
  - 升成远形式；需要 scratch 时用 `reserve` 的寄存器。

### `(term (return ...))` / `(term (trap))`

- 由 lower/ABI/平台层展开成具体序列。
- 不产生局部后继。

布局层可以**删除**冗余的 `(jump b)`：如果 `b` 就是下一块，这条边不需要
任何字节。但语义上这条边一直存在。

## 5. 函数间空隙

函数是闭合的：

- 没有跨函数边。
- 每个函数有自己的 `entry`。
- `return` / `trap` 不落到别的函数。

所以函数之间的 gap 只是 padding：

```text
func A
  ... (term (return ...))
  <gap>
func B
  ...
```

A 不会“掉进” B。gap 不需要前端插跳转。

如果某个 block 的边指向一个放在 gap 之后的 block，布局层会物化成跳转；
这是布局的职责，不是前端的职责。

## 6. block 顺序

block 在函数里的**文本顺序**是布局的首选顺序。前端可以通过排列 block 来
影响 fallthrough，例如：

```scheme
(block b0
  ...
  (term (branch (eq ($ t) 0) b2 b1)))

(block b1
  ...
  (term (jump b2)))

(block b2
  ...)
```

这里 `b1` 的 `(jump b2)` 可以物化成 fallthrough；`b0` 的第二个后继
（`b1`）是物理下一块，所以发射正向条件分支到第一个后继 `b2`，落下到 `b1`。

前端只控制**顺序意图**，不控制 `j` / `b` 的编码。

## 7. `j` / `b` 出现的位置

| 阶段 | 允许的形态 |
| --- | --- |
| virtual IR | `(term (jump ...))` / `(term (branch ...))` |
| machine IR | 同上，操作数已物化 |
| layout 后 | `label` + native 指令 + `j` / `b` / `jal` / `jalr` |
| encode | 字节 |

`j` / `b` 只出现在 layout 之后的扁平 item 流里；核心 IR 和 machine IR
都不直接写它们。

## 8. 间接控制流

当前核心只支持直接边。间接跳转/计算跳转以后单独设计，原则不变：

- 如果目标集合已知，就在 term 里显式列出；
- 如果目标集合未知，就把该函数标记为 opaque，不要假装 CFG 完整。

不要用裸 `jalr` 绕过 CFG。
