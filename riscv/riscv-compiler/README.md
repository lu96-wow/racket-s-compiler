# riscv-compiler

RISC-V s-expression 汇编器。

> **只认 `riscv-opcodes` native 顺序；不再提供 GAS 方言层。**

## 流水线

```text
rich-data ─→ expand-data ─┐
                          ↓
program-items ─┬─→ flatten ─→ [expand-pseudo] ─→ analyze ─→ dce ─→ relax ─→ bind-labels ─→ encode
data-items ────┘                                                                      │          │            │
                                                                                      ↓          ↓            ↓
                                                                                   measured     bound        build
```

- `[expand-pseudo]`：可选。便利别名（`load-8` / `store-*` / `branch-le`）→ native 指令。
- 默认流只跑 native：

```racket
'(expand-data flatten analyze dce relax bind-labels encode)
```

- 需要便利别名：

```racket
'(expand-data flatten expand-pseudo analyze dce relax bind-labels encode)
```

`layout` 仍然在 `relax` 内部反复跑。

## native 顺序

canonical 操作数顺序来自 `riscv-asm` 的 `instruction-info-operands`，去掉 `aq` / `rl`：

```scheme
(sw 8 sp t0)            ; simm12 rs1 rs2
(beq (L) a0 a1)         ; bimm12 rs1 rs2
(csrrw a0 a1 mstatus)   ; rd rs1 csr
(ble (L) a1 a0)         ; bimm12 rs2 rs1
```

`aq` / `rl` 仍然用助记符后缀：

```scheme
(amoadd.d.aqrl a0 a1 a2)
```

## 文档

| 文档 | 内容 |
| --- | --- |
| [`SURFACE-SYNTAX.md`](SURFACE-SYNTAX.md) | native 表面语法 |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 分层地图与 stage |
| [`SEXP.md`](SEXP.md) | 层间 s-exp 类型速查 |
| [`encode/syntax/DESIGN.md`](encode/syntax/DESIGN.md) | native plan / direct form |
| [`flow/DESIGN.md`](flow/DESIGN.md) | 构建流与硬边界 |
| `*/DESIGN.md` | 每层细节 |

## 跑

```bash
cd riscv-compiler
racket test/compiler-test.rkt
```

外部依赖：

- `../riscv-asm`：指令编码表
- `../riscv-help`：`li` / `la` / 远形式展开
