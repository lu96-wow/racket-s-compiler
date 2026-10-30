# riscv-compiler

从 s-expression 汇编走到字节。每层都是纯函数，可单独跑。

```
rich-data ─→ expand-data ─┐
                          ↓
program-items ─┬─→ flatten ─→ expand-pseudo ─→ analyze ─→ dce ─→ relax ─→ bind-labels ─→ encode
data-items ────┘                                │         │       │          │            │
                                                ↓         ↓       ↓          ↓            ↓
                                             program   program  measured   bound        build
```

- `layout` 在 `relax` 内部反复跑。
- `relax` 输出 measured-layout（只有 anchors，无绝对地址）。
- `bind-labels` 把 anchors 落到 symbols，输出可编码的 bound-layout。
- `encode` 只吃 bound-layout，并要求 requests / problems 为空。

## 文档

| 文档 | 内容 |
| --- | --- |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 分层地图与索引 |
| [`SEXP.md`](SEXP.md) | s-exp 类型速查 |
| [`flow/DESIGN.md`](flow/DESIGN.md) | 构建流 + **跨层硬边界** |
| [`CONSTRAINTS.md`](CONSTRAINTS.md) | **尺寸/布局/寄存器策略约束** |
| `*/DESIGN.md` | 每层：作用 / 相关 s-exp / 设计思路 |

## 跑

```bash
racket flow/test.rkt
racket flow/demo.rkt

racket expand-data/test.rkt
racket flatten/test.rkt
racket expand-pseudo/test.rkt
racket analyze/test.rkt
racket dce/test.rkt
racket layout/test.rkt
racket relax/test.rkt
racket bind-labels/test.rkt
racket encode/test.rkt

racket encode/demo.rkt
racket ../riscv-compiler-test/run.rkt
```

外部依赖：`../riscv-asm`（指令编码表）、`../riscv-help`（`li` / `la` / 远形式展开）。
