# flow（`flow.rkt`）

## 作用

用一张 stage 表 + 选择器串起各层。选择器可以写单层、层组或任意片段；
`run-stage` 只跑一层。

## 相关 s-exp / 在途值

| 名字 | 形状 | 谁产 |
| --- | --- | --- |
| `rich-data` | rich 数据 | seed / `expand-struct` |
| `structs` | struct 定义 + 布局 | `expand-struct` |
| `data-items` | 核心数据 item | `expand-data` / `flatten` / seed |
| `program-items` | 扁平程序 item（native） | seed / `expand-struct` / `flatten` |
| `names` | 完整链 → 位置 | `flatten` |
| `program` | `(struct program blocks flows)` | `analyze` / `dce` |
| `measured-layout` | segments + anchors + problems | `layout` / `check` |
| `bound-layout` | measured + symbols | `bind-labels` |
| `build` | link + provides + structs + 每段字节 | `encode` |

## stage 表

| stage | requires | provides |
| --- | --- | --- |
| `expand-struct` | `program-items` `rich-data` | `program-items` `rich-data` `structs` |
| `expand-data` | `rich-data` | `data-items` |
| `flatten` | `program-items` `data-items` (`optional externs`) | `program-items` `data-items` `names` `exports` |
| `analyze` | `program-items` `data-items` | `program` |
| `dce` | `program` | `program` |
| `layout` | `program` `data-items` `layout-spec` (`optional externs`) | `measured-layout` |
| `check` | `measured-layout` | `measured-layout` |
| `bind-labels` | `measured-layout` (`optional exports`) | `bound-layout` |
| `encode` | `bound-layout` (`optional structs`) | `build` |

## 层组

| 组名 | 展开 |
| --- | --- |
| `frontend` | `expand-struct expand-data flatten` |
| `ir` | `analyze dce` |
| `backend` | `layout check bind-labels encode` |
| `all` | `default-flow` |

默认流：

```racket
'(expand-struct expand-data flatten analyze dce layout check bind-labels encode)
```

## 硬边界

1. **`layout` / `check` 只产 measured-layout**：只有 `anchors`，没有绝对地址。
2. **绝对地址只由 `bind-labels` 产生**：`symbols` 只出现在 bound-layout。
3. **`encode` 只吃 bound-layout**：`phase` 不是 `bound`、或 `problems` 非空，一律拒绝。
4. **没有 requests**：短形式超范围、scratch/base/tmp 非法、近 la 够不着都是 `problems`。
   前端必须显式选择 `branch-jal` / `branch-auipc-jalr` / `jump-auipc-jalr` / `la-pcrel-li-add`。
5. **`check` 不改变尺寸**：只追加 problems，`segments` / `anchors` 原样传下去。
6. **`bind-labels` 是尺寸不变的收尾**：不松弛、不填 scratch、不补跳。
7. **寄存器策略**：会改尺寸的 regalloc/spill 必须在 `layout` 之前完成；
   `layout` 之后只能做尺寸不变的收尾。详见 [`../CONSTRAINTS.md`](../CONSTRAINTS.md)。
8. **层间只传 plain list 或 `struct program`**；不认识的 item 原样透传。
9. **target 是显式参数**：`layout` / `check` / `encode` 使用；`bind-labels` 不需要。
10. **谁产生 item，谁负责尺寸**；中间层不替 encode 做指令合法性检查。
11. **native 是唯一编码方言**：`encode` 只认 `instruction-info-operands` 顺序。
12. **形式选择也在前端**：后端不根据距离挑短/长形式。
13. **`expand-struct` 在 `layout` 之前**：struct 展开会改数据尺寸并生成 code item；它不依赖最终地址。
