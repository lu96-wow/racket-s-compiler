# layout（`forms.rkt` `layout.rkt`）

## 作用

放置与度量：把块/数据游程放进段，算偏移、尺寸，记 `anchors`，把范围检查分成
`requests` 和 `problems`。**不产出绝对地址。**

## 相关 s-exp

输入：

```racket
program                                  ; analyze/dce 的 block + flow
data-items                               ; label / bytes / fill / pad / value / align
((segments (segment (name …) (kind code|data) (start …) (end …) (align …)) …)
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

本层认识的数据 item：`label` / `bytes` / `fill` / `value` / `align` / `pad`。
其余 item 一律当不透明代码：4 字节，`c.*` 2 字节。

## 设计思路

- 单位：代码用 analyze 的块；数据用“从一条 label 到下一条 label”的游程。
- `place` 按精确链匹配；命中的块是锚点，后续块跟随；数据游程不跟随。
- `align` 在度量时换算成精确的 `(pad n)`；产物写事实，不写请求。
- 不透明代码的兜底 `4 字节 / 'code` 是设计，不是漏检。
- 只有 anchors + 段 start，所以本层只能算临时距离；`needs-far` / `la-too-far` 是请求。
- `(value w 表达式)` 这里只查链存在；宽度等最终地址定了再查。

## 边界

- 绝对地址、`value` 最终宽度、段容量：`bind-labels`。
- 松弛：`relax`。
- 填 scratch / `la` 远形式：未来寄存器层。
- 指令合法性、端序：`encode`。
- 补 fallthrough 跳转：未实现。
