# relax 分支松弛（`relax/relax.rkt`）

> 速览（功能 / s-exp / 设计理由）：[`../SEXP.md#relax`](../SEXP.md#relax)。
>
> 把够不着的控制转移换成"大一号"的形式，直到全部够得着。
> 只换 item，不造 label、不拆块、不改 CFG、**不填 scratch**、**不绑地址**。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| 消费 `requests` 里的 `needs-far`，升成远形式 | 填 `scratch-hole` / `la-too-far`（留给"寄存器使用"层） |
| 驱动 layout 重排到不动点 | 补 fallthrough 跳转 / trampoline / 块重排 |
| 返回 measured-layout | 绑绝对地址（bind-labels） |
| 保证单调收敛 | 造 label、改 CFG、改数据 |

## 2. 输入 / 输出

```racket
(relax program data layout-input)   ; -> measured-layout（needs-far 已销完）
(relax program data layout-input #:max-rounds 64)
```

**契约不是 `layout -> layout`**：layout 的产物已经排好偏移、没有块结构，改完没法重排。
所以本层**驱动** layout，而不是吃 layout 的产物。
输出仍是 measured-layout；绝对地址由 `bind-labels` 绑定。

```
loop:
  out   = layout(prog, data, layout-spec)
  edits = requests 里每个 needs-far -> far-step(item)
  没有 edits -> 停（把 out 返回）
  prog  = apply-edits(prog, edits)      ; 按 (code 块 项) 精确定位
```

## 3. API

| API | 输入 | 输出 |
| --- | --- | --- |
| `relax` | program + data + layout 输入 | measured-layout |
| `far-step` | 单条 item | 大一号的形式 / `#f`（到头了） |

## 4. 规则

### 4.1 提升阶梯（语义不变，尺寸只增）

| 原件 | 尺寸 | 升到 | 尺寸 |
| --- | --- | --- | --- |
| `c.beqz` / `c.bnez` | 2 | `beq` / `bne` | 4 |
| `c.j` / `c.jal` | 2 | `jal x0` / `jal ra` | 4 |
| `beq/bne/blt/bge/bltu/bgeu` | 4 | `(branch-far <cond> …)` | 8 |
| `branch-far` | 8 | `(branch-indirect <cond> …)` | 12 |
| `jal link` | 4 | `(jump-far link …)` | 8 |

一次只升一档，每轮重跑 layout。压缩形式先升到普通形式（还远就下一轮继续）。

### 4.2 为什么一定停（单调性）

每一次替换都让 item 变长 Δ > 0。对任意分支 `(q → t)`：

- `q`、`t` 都在变长点同一侧 → 距离不变；
- `q`、`t` 跨过变长点 → `|距离|` 增加 Δ。

所以"太远"的集合**单调递增**，已升级的不会降级，每个 item 最多升 3 档。
`#:max-rounds` 只是防呆（真超了说明提升表写错了）。

### 4.3 不造 label，所以 place 永远有效

远形式是**定长 item**（8 / 12），由 encode 展开成"反向条件分支 + 紧接着的跳转"
（与 gas `md_convert_frag_branch` 同形）。所以：

- 不需要给"跳过的 jal"造一个 label；
- `place` 行永远有效；
- `fallthrough` 不会因为松弛而断（远形式仍然是块的最后一条）。

LLVM 之所以要拆块 / 造块，是因为 MachineInstr 里没有"跳到 pc+8"这种操作数；
我们有伪指令洞，所以走 gas 那条路。

### 4.4 空槽不填

升到 `branch-indirect` / `(jump-far x0 …)` 会产生一个 **scratch 空槽**。
谁填、填哪个寄存器属于「动态内存布局 / 寄存器使用」那一层（**未实现**），
本层只把空槽留在 `requests` 的 `scratch-hole` 里当交接点，然后循环停下。

## 5. 不归本层管

- scratch 寄存器（未实现的那一层）。
- 绝对地址绑定、`value` 最终宽度、段容量（bind-labels）。
- `li` / `la` 的尺寸（`li` 精确、`la` 近形式固定，都不需要松弛）。
- 数据：`value` 的宽度是作者定的，尺寸固定，不参与松弛。

## 6. 测试（`relax/test.rkt`）

提升表逐条、一次收敛（`beq → branch-far`）、两轮（`c.beqz → beq → branch-far`）、
三级（>±1MB 产生空槽并停下）、`jal → jump-far`、边界 4092 / 4096、位置随尺寸重算、
`#:max-rounds` 保护。

## 7. 已知缺口

- 补 fallthrough 跳转、trampoline、块重排没做。
- 跨段到冷段没有 trampoline（LLVM 那条路），一律就地升形式。
- 空槽不填（等"寄存器使用"层）。
- 不绑绝对地址：输出 measured-layout，交给 bind-labels。
