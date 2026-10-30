# 架构索引

> 每层只关心自己的 s-exp 和设计。层作用、s-exp 类型、设计思路放在各自的 `DESIGN.md`。
> **跨层硬边界集中在 [`flow/DESIGN.md`](flow/DESIGN.md)**，本文只做地图。

## 流水线

```
rich-data ─→ expand-data ─┐
                          ↓
program-items ─┬─→ flatten ─→ expand-pseudo ─→ analyze ─→ dce ─→ relax ─→ bind-labels ─→ encode
data-items ────┘                                │         │       │          │            │
                                                ↓         ↓       ↓          ↓            ↓
                                             program   program  measured   bound        build
```

- `layout` 在 `relax` 内部被反复驱动；默认流不单独写 `layout`。
- `measured-layout` 只有 `anchors`，没有绝对地址。
- `bind-labels` 把 `anchors` 落到 `symbols`，产出可编码的 `bound-layout`。

## 层索引

| stage | 文件 | 作用 |
| --- | --- | --- |
| `expand-data` | `expand-data/expand.rkt` | rich 数据 → 核心数据 item |
| `flatten` | `flatten/flatten.rkt` | module / provide / require 的名字解析 |
| `expand-pseudo` | `expand-pseudo/rewrite.rkt` | 伪指令 → 真指令 |
| `analyze` | `analyze/analyze.rkt` | 切块 + 流 + root |
| `dce` | `dce/dce.rkt` | 死代码消除 |
| `layout` | `layout/layout.rkt` | 放置 + 尺寸 + anchors + requests/problems |
| `relax` | `relax/relax.rkt` | 分支松弛 |
| `bind-labels` | `bind-labels/bind.rkt` | anchors → symbols，最终宽度/容量检查 |
| `encode` | `encode/encode.rkt` | bound-layout → 每段字节 |
| `flow` | `flow/flow.rkt` | 用 stage 表 + 选择器串流程 |

每层细节：

- [`expand-data/DESIGN.md`](expand-data/DESIGN.md)
- [`flatten/DESIGN.md`](flatten/DESIGN.md)
- [`expand-pseudo/DESIGN.md`](expand-pseudo/DESIGN.md)
- [`analyze/DESIGN.md`](analyze/DESIGN.md)
- [`dce/DESIGN.md`](dce/DESIGN.md)
- [`layout/DESIGN.md`](layout/DESIGN.md)
- [`relax/DESIGN.md`](relax/DESIGN.md)
- [`bind-labels/DESIGN.md`](bind-labels/DESIGN.md)
- [`encode/DESIGN.md`](encode/DESIGN.md)
- [`encode/syntax/DESIGN.md`](encode/syntax/DESIGN.md)
- [`flow/DESIGN.md`](flow/DESIGN.md)

## 顶层共享模块

| 文件 | 内容 |
| --- | --- |
| `sexp.rkt` | form / name / path / as-items；地址表达式形状与 `eval-address(expr, resolve)` |
| `target.rkt` | `(struct target (xlen extensions))`；端序固定 little；`integer->bytes` / `padding-bytes` |

## 外部包

| 包 | 用途 |
| --- | --- |
| `../riscv-asm` | 指令编码表与位域检查 |
| `../riscv-help` | `li` / `la` / 远分支 / 远跳转展开与判据 |

## 文档约定

每层 `DESIGN.md` 只写三件事：

1. 这层做什么。
2. 它认识哪些 s-exp、吃什么/吐什么。
3. 为什么这样设计，以及它不碰什么。

跨层阶段、绝对地址、requests/problems、尺寸边界等硬规则放在 `flow/DESIGN.md`。
