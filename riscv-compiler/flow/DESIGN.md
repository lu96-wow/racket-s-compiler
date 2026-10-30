# flow（`flow.rkt`）

## 作用

用一张 stage 表 + 选择器串起各层。选择器可以写单层、层组或任意片段；
`run-stage` 只跑一层。

## 相关 s-exp / 在途值

| 名字 | 形状 | 谁产 |
| --- | --- | --- |
| `rich-data` | rich 数据 | seed |
| `data-items` | 核心数据 item | `expand-data` / `flatten` / seed |
| `program-items` | 扁平程序 item | seed / `flatten` / `expand-pseudo` |
| `names` | 完整链 → 位置 | `flatten` |
| `program` | `(struct program blocks flows)` | `analyze` / `dce` |
| `measured-layout` | segments + anchors + requests + problems | `layout` / `relax` |
| `bound-layout` | measured + symbols | `bind-labels` |
| `build` | 每段字节 | `encode` |

## stage 表

| stage | requires | provides |
| --- | --- | --- |
| `expand-data` | `rich-data` | `data-items` |
| `flatten` | `program-items` `data-items` | `program-items` `data-items` `names` |
| `expand-pseudo` | `program-items` | `program-items` |
| `analyze` | `program-items` `data-items` | `program` |
| `dce` | `program` | `program` |
| `layout` | `program` `data-items` `layout-spec` | `measured-layout` |
| `relax` | `program` `data-items` `layout-spec` | `measured-layout` |
| `bind-labels` | `measured-layout` | `bound-layout` |
| `encode` | `bound-layout` | `build` |

## 层组

| 组名 | 展开 |
| --- | --- |
| `frontend` | `expand-data flatten expand-pseudo` |
| `ir` | `analyze dce` |
| `backend` | `relax bind-labels encode` |
| `all` | `default-flow` |

默认流：

```racket
'(expand-data flatten expand-pseudo analyze dce relax bind-labels encode)
```

## 硬边界

1. **`layout` / `relax` 只产 measured-layout**：只有 `anchors`，没有绝对地址。
2. **绝对地址只由 `bind-labels` 产生**：`symbols` 只出现在 bound-layout。
3. **`encode` 只吃 bound-layout**：`phase` 不是 `bound`、或 `requests` / `problems` 非空，一律拒绝。
4. **`requests` ≠ `problems`**：
   - `requests`：`needs-far` / `scratch-hole` / `la-too-far`，交给后续 pass。
   - `problems`：放置 / 段 / fallthrough / `undefined-target` / 最终宽度/容量。
5. **`bind-labels` 是尺寸不变的收尾**：不松弛、不填 scratch、不补跳。
   凡会改变尺寸的 pass（relax、未来的 la-far 展开）必须在它之前收敛。
6. **寄存器层的位置**：`relax` 之后、`bind-labels` 之前；它消费 `scratch-hole` / `la-too-far`，
   返回 measured-layout。
7. **`layout` 和 `relax` 是平层**：`requires` / `provides` 相同，写 `relax` 就够了。
8. **层间只传 plain list 或 `struct program`**；不认识的 item 原样透传。
9. **target 是显式参数**：`layout` / `relax` / `encode` 使用；`bind-labels` 不需要。
10. **谁产生 item，谁负责尺寸**；中间层不替 encode 做指令合法性检查。
