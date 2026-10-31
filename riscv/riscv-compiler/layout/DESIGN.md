# layout（`forms.rkt` `layout.rkt`）

## 作用

放置与度量：把块/数据游程放进段，算偏移、尺寸，记 `anchors`，把范围检查分成
`requests` 和 `problems`。**不产出绝对地址。**

## 相关 s-exp

输入：

```racket
program                                  ; analyze/dce 的 block + flow
data-items                               ; label / bytes / fill / pad / value / align / reserve
((segments (segment (name …) (kind code|data|hole) (start …) (end …) (align …)) …)
 (place 段名 链 …) …)
```

输出 measured-layout：

```racket
((phase measured)
 (segments (segment (name …) (kind …) (start …) (end …) (align …)
                    (items (offset k item) …)
                    (size n)) …)
 (anchors (anchor 链 段名 偏移) …)
 (requests (needs-far …) (scratch-hole …) (la-too-far …))
 (problems (unplaced …) (undefined-target …) …))
```

本层认识的数据 item：`label` / `bytes` / `fill` / `value` / `align` / `pad` / `reserve`。
其余 item 一律当不透明代码：4 字节，`c.*` 2 字节。

## item 类别

合法性只有一张表（`forms.rkt` 的 `item-kind-allowed-in?`），本层不另写策略：

| 类别 | item | code | data | hole |
| --- | --- | --- | --- | --- |
| `marker` | `label` | ✓ | ✓ | ✓ |
| `align` | `align` | ✓ | ✓ | ✓ |
| `pad` | `pad`（本层产的对齐事实） | ✓ | ✓ | ✗ |
| `space` | `reserve` | ✗ | ✗ | ✓ |
| `materialized` | `bytes` / `fill` / `value` | ✗ | ✓ | ✗ |
| `code` | 指令 | ✓ | ✗ | ✗ |

## hole 段（有位置，没有文件字节）

- `align` 的产物按段 kind 归一化：`code`/`data` 变 `(pad n)`，`hole` 变 `(reserve n)`。
  这是本层**唯一的 kind 分叉**。
- 因此 hole 段的 items 永远只含 `label` / `reserve`：encode 不用再判“洞从哪儿开始”，
  “这段是洞”是段声明，不是运行时状态。
- `size` 照常累加（`reserve` 也推进游标），所以 anchor 和容量检查与其他段一致。
- 空 hole（`start == end`）合法；没有 item、没有 `place` 的 hole 就是 guard page / MMIO 窗口。
- 本层**不解释**洞里的内容；清零与否、谁清，是前端/平台的事。

本层为此报的两个问题（其余沿用）：

| 名字 | 条件 |
| --- | --- |
| `hole-materialized-item` | `hole` 段里出现 `pad` / `bytes` / `fill` / `value` / 指令 |
| `reserve-outside-hole` | `reserve` 出现在 `code` / `data` 段 |

## 设计思路

- 单位：代码用 analyze 的块；数据用“从一条 label 到下一条 label”的游程。
- `place` 按精确链匹配；命中的块是锚点，后续块跟随；数据游程不跟随。
- `align` 在度量时换算成精确事实；产物写事实，不写请求。
  补出来的是 `(pad n)` 还是 `(reserve n)` 由段 kind 定（见上）。
- 不透明代码的兜底 `4 字节 / 'code` 是设计，不是漏检。
- 只有 anchors + 段 start，所以本层只能算临时距离；`needs-far` / `la-too-far` 是请求。
- `(value w 表达式)` 这里只查链存在；宽度等最终地址定了再查。

## 边界

- 绝对地址、`value` 最终宽度、段容量：`bind-labels`。
- 松弛：`relax`。
- 填 scratch / `la` 远形式：未来寄存器层。
- 指令合法性、端序：`encode`。
- 补 fallthrough 跳转：未实现。
