# amd64 flow

> 用 stage 表 + 选择器串起 amd64 各层。默认流包含 `relax`：expand-pseudo 先产生
> short branch，relax 再按需要升成 near。

## stage 表

| stage | requires | provides |
| --- | --- | --- |
| `loko-compat` | `loko-source` | `program-items` `data-items` `loko-aliases` |
| `expand-data` | `rich-data` | `data-items` |
| `flatten` | `program-items` `data-items` | `program-items` `data-items` `names` |
| `expand-pseudo` | `program-items` | `program-items` |
| `analyze` | `program-items` `data-items` | `program` |
| `dce` | `program` | `program` |
| `layout` | `program` `data-items` `layout-spec` | `measured-layout` |
| `relax` | `program` `data-items` `layout-spec` | `measured-layout` |
| `bind-labels` | `measured-layout` | `bound-layout` |
| `encode` | `bound-layout` | `build` |

默认流：

```racket
'(expand-data flatten expand-pseudo analyze dce relax bind-labels encode)
```

Loko 兼容流：

```racket
'(loko-compat expand-pseudo analyze dce relax bind-labels encode)
```

对应阶段组是 `'loko`。`loko-compat` 只把旧写法变成核心 item；`%section` /
`%comm` / `%origin` / `%mode` / `%call` 留给 image 层，当前会作为 problem 报错。

## 说明

- `loko-compat` 是非强制入口；核心流不认识 Loko 的 `memN+` / `%label` 等拼写。
- `layout` 直接消费 `program` 的 blocks + flows 和 data runs；检查 placement、段、fallthrough、RIP/disp32 范围。
- `layout-items` 只是扁平 item 的兼容入口，不消费 flows。
- `measured-layout` 只有 anchors，没有绝对地址。
- `relax` 和 `layout` 平层：自己反复驱动 layout，消费 `needs-near`。
- `bind-labels` 才产生 symbols / 绝对地址。
- `encode` 只吃 bound-layout；有 requests/problems 就拒绝。
