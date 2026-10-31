# amd64 flow

## 作用

用 stage 表 + 选择器把 amd64 各层串起来。默认流包含 relax：
`expand-pseudo` 先产生 short branch，`relax` 再按需要升成 near。

## 相关 s-exp / 在途值

| 名字 | 形状 | 谁产 |
| --- | --- | --- |
| `loko-source` | `(loko-source (text …) (data …))` | seed |
| `loko-aliases` | `(alias 名字 值) …` | `loko-compat` |
| `loko-ir` | sections / origin / modes / symbols / comms | `loko-compat` |
| `rich-data` | rich 数据 | seed |
| `data-items` | 核心数据 item | `expand-data` / `flatten` / seed |
| `program-items` | 扁平程序 item | seed / `flatten` / `expand-pseudo` / `loko-compat` |
| `names` | 完整链 → 位置 | `flatten` |
| `program` | `(struct program blocks flows)` | `analyze` / `dce` |
| `layout-spec` | `(segments …) (place …)` | seed |
| `measured-layout` | segments + anchors + requests + problems | `layout` / `relax` |
| `bound-layout` | measured + symbols | `bind-labels` |
| `build` | 每段字节 | `encode` |

## stage 表

| stage | requires | provides |
| --- | --- | --- |
| `loko-compat` | `loko-source` | `program-items` `data-items` `loko-aliases` `loko-ir` |
| `loko-lower` | `loko-ir` | `loko-ir` |
| `loko-image` | `loko-ir` | `program-items` `data-items` `layout-spec` |
| `expand-data` | `rich-data` | `data-items` |
| `flatten` | `program-items` `data-items` | `program-items` `data-items` `names` |
| `expand-pseudo` | `program-items` | `program-items` |
| `analyze` | `program-items` `data-items` | `program` |
| `dce` | `program` | `program` |
| `layout` | `program` `data-items` `layout-spec` | `measured-layout` |
| `relax` | `program` `data-items` `layout-spec` | `measured-layout` |
| `bind-labels` | `measured-layout` | `bound-layout` |
| `encode` | `bound-layout` | `build` |

## 设计思路

- 默认流：

  ```racket
  '(expand-data flatten expand-pseudo analyze dce relax bind-labels encode)
  ```

- Loko 自动流：

  ```racket
  '(loko-compat loko-lower loko-image expand-pseudo analyze dce relax bind-labels encode)
  ```

  对应阶段组是 `'loko`。

- Loko 手动 layout-spec 流：

  ```racket
  '(loko-compat loko-lower expand-pseudo analyze dce relax bind-labels encode)
  ```

  对应阶段组是 `'loko-manual`。

- `layout` 与 `relax` 平层：`relax` 自己反复驱动 `layout`。
- `layout` 直接消费 `program` 的 blocks + flows 和 data runs。
- `layout-flat-items` 只是扁平 item 的兼容入口，不消费 flows。
- `measured-layout` 只有 anchors，没有绝对地址。
- `bind-labels` 才产生 symbols / 绝对地址。
- `encode` 只吃 bound-layout；有 requests/problems 就拒绝。
- stage 名字是契约；目录名不是流的一部分。
- 选择器支持单层、层组和任意片段；组只是预定义列表，没有额外语义。

## 边界

- 不实现任何层语义，只做组合。
- 不替层隐藏依赖；缺 requires 直接报错并列出 providers。
- `loko-compat` 采集 `%section` / `%origin` / `%mode` / `%comm` 到 `loko-ir`；
  当前只有 `%call` 仍作为问题报错。
- `loko-lower` 已把 `loko-ir` 的 code section 从 `(reg N)` 降到物理寄存器。
- `loko-image` 已把 `loko-ir` 自动转成粗布局 `layout-spec`；
  需要自己提供 layout-spec 时用 `'loko-manual`。
