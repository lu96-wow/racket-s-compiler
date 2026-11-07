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
 (origin 镜像基址)        ; spec 的 (origin …)，缺省 0；给 link 表当锚
 (externs (symbol 链 地址|#f) …)   ; 输入侧 link 表的行，原样带下去
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
- 没有 item、没有 `place` 的 hole 就是 guard page / MMIO 窗口。
- 本层**不解释**洞里的内容；清零与否、谁清，是前端/平台的事。

本层为此报的两个问题（其余沿用）：

| 名字 | 条件 |
| --- | --- |
| `hole-materialized-item` | `hole` 段里出现 `pad` / `bytes` / `fill` / `value` / 指令 |
| `reserve-outside-hole` | `reserve` 出现在 `code` / `data` 段 |

## 设计思路

- 单位：代码用 analyze 的块；数据用“从一条 label 到下一条 label”的游程。
- 控制转移的目标位置来自 `analyze/insn.rkt` 的 `jump-target` /
  `jump-target-position`，不假设 native 分支的目标在最后。
- `place` 按精确链匹配；命中的块是锚点，后续块跟随；数据游程不跟随。
- `align` 在度量时换算成精确事实；产物写事实，不写请求。
  补出来的是 `(pad n)` 还是 `(reserve n)` 由段 kind 定（见上）。
- 不透明代码的兜底 `4 字节 / 'code` 是设计，不是漏检。
- 地址求解：段声明里 `(start …)` 是解、可以缺省；缺省时 `start = align-up 游标 align`，
  游标等于上一个段的 `end`，起点是 spec 的 `(origin …)`。`(size …)` 会变成
  `end = start + size`。求解后各层只看到整数地址。
- 段范围：`start <= end` 合法（空段是常态：还没有内容的 section，或者还没占地址的洞）；
  只有 `end < start` 报 `segment-bad-range`。和 amd64 同一条规则。
- 只有 anchors + 段 start，所以本层只能算临时距离；`needs-far` / `la-too-far` 是请求。
- `(value w 表达式)` 这里只查链存在；宽度等最终地址定了再查。

## 外部符号（输入侧的 link 表）

`layout-program` 收一个可选的 `externs`：就是 `externs.rkt` 解析出来的
`(symbol 链 地址|#f)` 行。它们**不是**本镜像的 label，不占字节、不参与放置、
不参与 fallthrough，只提供两样东西：

- **地址**：并进本层的临时位置表（`positions`），于是距离判断
  （`needs-far` / `la-too-far` / `value` 的链检查）对它们照常工作；
- **自检**：
  - `(external-conflict 链)`：名字和本镜像的 label 撞了（撞了 `symbol-row` 会静默挑一个）
  - `(unlinked-external 链)`：地址是 `#f` —— 没有 reloc 层，编不出来。宁可拒绝，
    也不产出一个“看着能跑”的镜像。引用它的 item 不再重复报 `undefined-target`
    （那不是“未定义”，是“还不知道”）
  - `(misaligned-external 链 地址)`：奇数地址不能当 `branch`/`jal`/`jalr` 的目标
    （立即数忽略 bit0，`jalr` 还会清 bit0）

`base` 字段只解析、不参与算术：地址是绝对的，距离就是两个绝对地址相减。
它真正的用途是“整体搬迁”（所有地址加 Δ）时的锚，等做重定位层再校验。
外部符号**不进**产物的 `link` / `provides` —— 那不是本镜像提供的东西。

## 边界

- 绝对地址、`value` 最终宽度、段容量：`bind-labels`。
- 松弛：`relax`。
- 填 scratch / `la` 远形式：未来寄存器层。
- 指令合法性、端序：`encode`。
- 补 fallthrough 跳转：未实现。
