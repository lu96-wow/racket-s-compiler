# dce 死代码消除（`dce/dce.rkt`）

> 第一个**改**控制流的层：`program -> program`。只动可达性、冗余转移、空块。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| 删从 root 走不到的块 | 改 item 的内容（除了删转移） |
| 删"跳到紧邻下一块"的转移 | 改 label 名字 |
| 空块并进下一块 | 补跳（`broken-fallthrough` 的修复不属于本层） |

## 2. 输入 / 输出

```racket
(program blocks flows) -> (program blocks flows)
```

每个 pass 都**同时**改 `blocks` 和 `flows`，改完统一**重新编号**（位置即 id），
`succ` / `fallthrough` 跟着重映射。

## 3. API

| API | 输入 | 输出 |
| --- | --- | --- |
| `optimize-program` | program | program（三个 pass 跑到不动点，最多 16 轮） |
| `eliminate-dead` | program | program（`optimize-program` 的别名） |
| `passes` | — | `((名字 . 函数) ...)` |
| `pass-names` | — | 名字列表 |

`passes` = `drop-unreachable` → `drop-transfers-to-next-block` → `merge-empty-blocks`，
最多 16 轮（`max-rounds`）。

## 4. 规则

| pass | 做什么 | 为什么安全 |
| --- | --- | --- |
| `drop-unreachable` | 从 `root?` 走不到的块删掉 | `root?` 由 analyze 定，包含数据侧取地址 |
| `drop-transfers-to-next-block` | 最后一条是（无条件的跳转 / 分支）且目标就是物理下一块 → 删掉，变成顺序落下 | 两条路都到同一处，转移是空的 |
| `merge-empty-blocks` | 没有 item 的空块，其 label 与下一块同址，并进下一块（末尾空块保留） | label 地址不变 |

删转移用 `unconditional-jump?` / `branch-instruction?`，所以**远形式也适用**：
`(branch-far beq …)`、`(jump-far ra …)` 目标紧邻时照样会被删掉。

## 5. 不归本层管

- `broken-fallthrough`（顺序执行被段剪断）：layout 只报，补跳不属于本层。
- 分支松弛（超范围升形式）：relax。
- 尺寸 / 地址：layout。

## 6. 测试（`dce/test.rkt`，46 条）

三个 pass 各自的行为、混合跑到不动点、远形式也会被删、空块合并后 label 地址不变、
`root?` 缺失时不该删的块保留。

## 7. 已知缺口

- 没有窥孔 / 常量折叠 / 跳转链折叠（`jal x0 L; … L: jal x0 M`）。
- 没有块重排（布局顺序 = 源顺序）。
