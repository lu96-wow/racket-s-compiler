# amd64 core flow

> 本文只描述 `compiler/flow/core.rkt` 的核心汇编流。
> Loko / ELF 等可选阶段见 [`../../loko-compatibility/DESIGN.md`](../../loko-compatibility/DESIGN.md)。

## 作用

用 stage 表 + 选择器把核心 amd64 各层串起来。默认流不做分支松弛：
`expand-pseudo` 默认产生 near branch，short 只能由前端显式写；
`layout` 一次度量，超范围就是 problem。

## 相关 s-exp / 在途值

| 名字 | 形状 | 谁产 |
| --- | --- | --- |
| `rich-data` | rich 数据 | seed |
| `data-items` | 核心数据 item | `expand-data` / `flatten` / seed |
| `program-items` | 扁平程序 item | seed / `flatten` / `expand-pseudo` |
| `names` | 完整链 → 位置 | `flatten` |
| `program` | `(struct program blocks flows)` | `analyze` / `dce` |
| `layout-spec` | `(segments …) (place …)` | seed |
| `measured-layout` | segments + anchors + problems | `layout` |
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
| `bind-labels` | `measured-layout` | `bound-layout` |
| `encode` | `bound-layout` | `build` |

## 设计思路

- 默认流：

  ```racket
  '(expand-data flatten expand-pseudo analyze dce layout bind-labels encode)
  ```

- 核心层组：`frontend` / `ir` / `backend` / `all`。
- `layout` 直接消费 `program` 的 blocks + flows 和 data runs。
- `layout-flat-items` 只是扁平 item 的兼容入口，不消费 flows。
- `measured-layout` 只有 anchors，没有绝对地址。
- `bind-labels` 才产生 symbols / 绝对地址。
- `encode` 只吃 bound-layout；有 problems 就拒绝。
- 没有 requests：显式 short 超范围、near 超范围都由 `layout` 报 `out-of-range`。
- stage 名字是契约；目录名不是流的一部分。
- 选择器支持单层、层组和任意片段；组只是预定义列表，没有额外语义。

## 边界

- 只注册核心汇编层；不 require Loko、ELF 或任何可选前端/镜像层。
- 不实现任何层语义，只做组合。
- 不替层隐藏依赖；缺 requires 直接报错并列出 providers。
- 可选前端通过 `extend-flow` 注册自己的阶段和层组，不修改本文件。
