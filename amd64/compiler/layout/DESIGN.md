# amd64 layout

> program blocks + data runs + layout-spec -> measured-layout。
> 本层只做放置、度量、anchors、requests、problems；不选远形式、不绑绝对地址。

## 输入

```racket
(layout-program target program data-items spec)
```

`program` 是 `analyze` / `dce` 的产物：

```text
blocks: (block <头 label 链列表> item ...)
flows : (flow (succ ...) (fallthrough id|#f) (root? bool))
```

数据侧按 label 切成 `run`：一条 label 到下一条 label。

`spec`：

```scheme
'((segments
   (segment (name text) (kind code) (start #x200000) (end #x201000) (align 16))
   (segment (name data) (kind data) (start #x300000) (end #x301000) (align 8))
   (segment (name bss) (kind hole) (start #x400000) (end #x401000) (align 16)))
  (place text (text))      ; 精确匹配
  (place data (data))
  (place text *))          ; 可选：未命中的块/run 落到 text
```

## 放置规则

- `place` 的链按**精确路径**匹配块头 label 或数据 run 的 label。
- 代码块命中 `place` 后，后续块跟随该段，直到下一个命中。
- 数据 run 必须自己命中 `place`，不跟随。
- `*` 是显式 wildcard，只作为没有精确命中的兜底。
- 没有命中也没有 wildcard 的块/run 报 `unplaced-block` / `unplaced-data`。

## item 类别

`item-kind`（`compiler/item.rkt`）只回答“这条 item 是什么”；能不能放进某段由
本层的表 `item-kind-allowed-in?`（`layout/forms.rkt`）回答：

| 类别 | item | code | data | hole |
| --- | --- | --- | --- | --- |
| `marker` | `label` / `comment` | ✓ | ✓ | ✓ |
| `align` | `align` | ✓ | ✓ | ✓ |
| `pad` | `pad`（本层产的对齐事实） | ✓ | ✓ | ✗ |
| `space` | `reserve` | ✗ | ✗ | ✓ |
| `materialized` | `bytes` / `fill` / `value` | ✓ | ✓ | ✗ |
| `code` | 指令 | ✓ | ✗ | ✗ |

`code` 段收 `materialized` 是有意的：ELF/multiboot header、跳转表都放那里。

## 度量

- `align` 按**绝对地址** `start + cursor` 换算成事实；产物写事实，不写请求。
  补出来的是 `(pad n)` 还是 `(reserve n)` 由段 kind 定（见下）。
- `comment` 零尺寸，不进入 items。
- item 尺寸来自 `layout/forms.rkt` -> `instruction-size`。
- 段起始对齐、段重叠、段容量都在本层检查；空段允许 `start == end`
  （自动布局会产出没内容的 data section）。

## hole 段（有位置，没有文件字节）

- `align` 在 hole 段里归一化成 `(reserve n)`，在 code/data 段里是 `(pad n)`。
  这是本层**唯一的 kind 分叉**。
- 因此 hole 段的 items 永远只含 `reserve`（label 在 amd64 只进 anchors）：
  encode 不用再判“洞从哪儿开始”，“这段是洞”是段声明，不是运行时状态。
- 本层**不解释**洞里的内容；是 0 还是别的、谁来写，是前端 / loader 的事。
- 问题名：hole 段里出现要写字节的 item 报 `hole-materialized-item`；
  `reserve` 出现在 code/data 段报 `reserve-outside-hole`；
  其余不合法组合仍是 `segment-item-kind-mismatch`。

## 校验

- 控制转移目标必须存在；距离超出 form 的 range：
  - short -> `needs-near` request
  - near -> `needs-far` request
- 符号内存 displacement：
  - RIP-relative 目标必须在 rel32 范围
  - 绝对 disp32 必须在可编码范围
- 数据 `value` 里的地址表达式链必须存在；宽度最终由 bind/encode 检查。
- `fallthrough`：段的代码块顺序里，顺序后继必须紧挨着；否则报
  `broken-fallthrough`。

## 产物

```scheme
((phase measured)
 (segments (segment (name ...) (kind ...) (start ...) (end ...)
                    (items (offset k item) ...) (size n)) ...)
 (anchors (anchor 链 段名 偏移) ...)
 (requests ...)
 (problems ...))
```

requests 里的 `origin` 是：

```text
(code 块下标 项下标)
(data run下标 项下标)
(flat unit下标 项下标)      ; layout-flat-items 兼容入口
```

relax 只消费 `needs-near` 的 `(code ...)` origin。

## 已知限制

- `place` 没有 region 语法；region 是通过“块跟随当前段”实现的。
- 还没有 far form / trampoline / scratch-fill。
- `layout-flat-items` 是兼容入口，不消费 flows，不做 fallthrough 检查。
