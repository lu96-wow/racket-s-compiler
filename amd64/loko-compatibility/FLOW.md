# Loko / ELF optional flow

> 本文只描述 `loko-compatibility/flow.rkt` 在核心 `core-flow` 上追加的阶段。
> 核心阶段表见 [`../compiler/flow/DESIGN.md`](../compiler/flow/DESIGN.md)。

## 作用

`loko-compatibility/flow.rkt` 是唯一知道 Loko 兼容层和 `amd64-elf` 的 flow。
它用 `extend-flow core-flow` 注册可选阶段和层组；`compiler/` 不依赖它们。

## 追加的在途值

| 名字 | 形状 | 谁产 |
| --- | --- | --- |
| `loko-source` | `(loko-source (text …) (data …))` | seed |
| `loko-ir` | sections / origin / modes / symbols / comms / image-plan | `loko-compat` / `loko-lower` |
| `image` | ELF64 image | `loko-elf` |

## 追加的 stage

| stage | requires | provides |
| --- | --- | --- |
| `loko-compat` | `loko-source` | `program-items` `data-items` `loko-ir` |
| `loko-lower` | `loko-ir` | `loko-ir` |
| `loko-image` | `loko-ir` | `program-items` `data-items` `layout-spec` |
| `expand-pseudo-near` | `program-items` | `program-items`（near-only 验证变体） |
| `loko-elf` | `build` `bound-layout` `loko-ir` | `image` |

## 层组

| 组名 | 展开 |
| --- | --- |
| `loko` | `loko-compat loko-lower loko-image expand-pseudo analyze dce relax bind-labels encode` |
| `loko-manual` | `loko-compat loko-lower expand-pseudo analyze dce relax bind-labels encode` |
| `loko-near` | `loko-compat loko-lower loko-image expand-pseudo-near analyze dce layout bind-labels encode` |
| `elf` | `loko-compat loko-lower loko-image expand-pseudo analyze dce relax bind-labels encode loko-elf` |
| `elf-manual` | `loko-compat loko-lower expand-pseudo analyze dce relax bind-labels encode loko-elf` |

## 边界

- 本流不修改 `core-flow`，只追加阶段/层组。
- `loko-compat` 采集 `%section` / `%origin` / `%mode` / `%comm` 等 Loko 元数据；
  核心编译器只看到普通 `program-items` / `data-items` / `layout-spec`。
- `loko-lower` 负责 `(reg N)` / 寄存器分配 / Loko 调用约定；核心编译器不依赖它。
- `loko-image` 把 `loko-ir` 变成粗布局 `layout-spec`；需要自己提供 layout-spec 时用
  `loko-manual`。
- `loko-elf` 调用 `amd64-elf/writer.rkt`；核心 compiler 不依赖 ELF writer。
- `compile-image` 默认跑 `elf`，返回 `(elf ...)`。
