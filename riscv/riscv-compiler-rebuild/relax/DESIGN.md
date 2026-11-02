# relax（`relax.rkt`）

## 作用

分支松弛：消费 `requests` 里的 `needs-far`，把控制转移升成“大一号”的形式，
直到全部够得着。输出仍是 measured-layout。

## 相关 s-exp

`requests` 里的：

```racket
(needs-far 段 偏移 item 距离 (code 块 项))
```

提升表：

| 原件 | 升到 |
| --- | --- |
| `c.beqz` / `c.bnez` | `beq` / `bne` |
| `c.j` / `c.jal` | `jal x0` / `jal ra` |
| `beq/bne/blt/bge/bltu/bgeu` | `(branch-far <cond> …)` |
| `branch-far` | `(branch-indirect <cond> …)` |
| `jal link` | `(jump-far link …)` |

## 设计思路

- 每轮重跑 `layout`：layout 产物没有块结构，不能原地重排。
- 每次替换只让 item 变长，距离单调不减，因此“太远”集合单调递增，必然收敛。
- 不造 label、不拆块、不改 CFG，所以 `place` 和 `fallthrough` 永远有效。
- `scratch-hole` / `la-too-far` 不填，原样留在 `requests`。

## 边界

不绑地址、不填 scratch、不补跳、不重排、不改数据宽度。
