# riscv-compiler 架构

> 每层只关心自己的 s-exp 和设计。层作用、s-exp 类型、设计思路放在各自的 `DESIGN.md`。
> 人写的输入语法见 [`SYNTAX.md`](SYNTAX.md)。
> **跨层硬边界集中在 [`flow/DESIGN.md`](flow/DESIGN.md)**；尺寸/寄存器策略约束见 [`CONSTRAINTS.md`](CONSTRAINTS.md)。本文只做地图。

## 流水线

```
rich-data + program-items
  -> expand-struct
  -> expand-data
  -> flatten
  -> analyze
  -> dce
  -> layout
  -> check
  -> bind-labels
  -> encode
  -> build
```

- 输入是 canonical native；没有可选别名层。
- `expand-struct` 是前端布局展开层：struct 定义、静态数据、字段访问。
- `layout` 只度量位置；`check` 检查显式形式，不改尺寸。
- `measured-layout` 只有 `anchors`，没有绝对地址。
- `bind-labels` 把 `anchors` 落到 `symbols`，产出可编码的 `bound-layout`。

## 外部调用方：`api.rkt`

本目录里的 `encode/insn.rkt`、`target.rkt` 是**内部模块**。其它后端 / 前端
（`riscv-core`、未来的 L0 降级器）只允许 require
[`api.rkt`](api.rkt)：它 re-provide `encode-instruction` /
`instruction-arity` / `known-instruction?` 和 target 事实。

这样这两个模块将来搬到共享层（例如 `riscv-encode/`）时，只有一个文件要改。

## 层索引

| stage | 文件 | 作用 |
| --- | --- | --- |
| `expand-struct` | `struct/struct.rkt` | struct 布局 + 静态数据 + 字段访问展开 |
| `expand-data` | `expand-data/expand.rkt` | rich 数据 → 核心数据 item |
| `flatten` | `flatten/flatten.rkt` | label 名字空间的 module / provide / require 解析 |
| `analyze` | `analyze/analyze.rkt` | 切块 + 流 + root；操作数位置按 native |
| `dce` | `dce/dce.rkt` | 死代码消除 |
| `layout` | `layout/layout.rkt` | 放置 + 尺寸 + anchors/problems；不选形式 |
| `check` | `check/check.rkt` | 检查显式控制转移/地址形式；只报 problems |
| `bind-labels` | `bind-labels/bind.rkt` | anchors → symbols，最终宽度/容量检查 |
| `encode` | `encode/encode.rkt` | bound-layout → 每段字节 |
| `flow` | `flow/flow.rkt` | 用 stage 表 + 选择器串流程 |

每层细节：

- [`SYNTAX.md`](SYNTAX.md)
- [`STRUCT.md`](STRUCT.md)
- [`struct/DESIGN.md`](struct/DESIGN.md)
- [`expand-data/DESIGN.md`](expand-data/DESIGN.md)
- [`flatten/DESIGN.md`](flatten/DESIGN.md)
- [`analyze/DESIGN.md`](analyze/DESIGN.md)
- [`dce/DESIGN.md`](dce/DESIGN.md)
- [`layout/DESIGN.md`](layout/DESIGN.md)
- [`check/DESIGN.md`](check/DESIGN.md)
- [`bind-labels/DESIGN.md`](bind-labels/DESIGN.md)
- [`encode/DESIGN.md`](encode/DESIGN.md)
- [`encode/syntax/DESIGN.md`](encode/syntax/DESIGN.md)
- [`flow/DESIGN.md`](flow/DESIGN.md)
- [`CONSTRAINTS.md`](CONSTRAINTS.md)

## 顶层共享模块

| 文件 | 内容 |
| --- | --- |
| `sexp.rkt` | form / name / path / as-items；地址表达式形状与 `eval-address(expr, resolve)` |
| `modules.rkt` | 共享模块树 + provide/require/prefix/rename/re-export 不动点；label 和 struct 各自提供声明表 |
| `meta.rkt` | 带标签元数据的公共读取器：`tagged-form?` / `tag-ref` / `tag-ref*` |
| `struct-meta.rkt` | struct 元数据 `struct-def` ↔ `sdef`，以及 `sdef` → 布局无关声明 |
| `unit.rkt` | 布局前接口：模块可见性 + label kind + struct 声明 |
| `target.rkt` | `(struct target (xlen extensions))`；端序固定 little；`integer->bytes` / `padding-bytes` |

## 外部包

| 包 | 用途 |
| --- | --- |
| `../riscv-asm` | 指令编码表与位域检查 |
| `../riscv-help` | `li` / `la` / 显式分支跳转展开、判据、`instruction-size` |

## 文档约定

每层 `DESIGN.md` 只写三件事：

1. 这层做什么。
2. 它认识哪些 s-exp、吃什么/吐什么。
3. 为什么这样设计，以及它不碰什么。

跨层阶段、绝对地址、problems 等硬规则放在 `flow/DESIGN.md`；尺寸与寄存器策略约束放在 `CONSTRAINTS.md`。
