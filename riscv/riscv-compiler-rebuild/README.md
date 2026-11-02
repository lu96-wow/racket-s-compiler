# riscv-compiler-rebuild

`riscv-compiler` 的重构版，和原目录并列保留，方便逐层比对。

重构目标：

> **底层只认 `riscv-opcodes` native 顺序；GAS 顺序是可选的前端重写层，不是 canonical。**

## 流水线

```text
rich-data ─→ expand-data ─┐
                          ↓
program-items ─┬─→ flatten ─→ [gas-syntax] ─→ [expand-pseudo] ─→ analyze ─→ dce ─→ relax ─→ bind-labels ─→ encode
data-items ────┘                                                                      │          │            │
                                                                                      ↓          ↓            ↓
                                                                                   measured     bound        build
```

- `[gas-syntax]`：可选。GAS 操作数顺序 → native 顺序。
- `[expand-pseudo]`：可选。便利别名（`load-8` / `store-*` / `branch-le`）→ native 指令。
- 默认流只跑 native：

```racket
'(expand-data flatten analyze dce relax bind-labels encode)
```

- 需要 GAS 写法：

```racket
'(expand-data flatten gas-syntax analyze dce relax bind-labels encode)
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

## GAS 层

`gas-syntax` 是纯表替换，只做顺序变换：

```scheme
(sw t0 sp 8)             -> (sw 8 sp t0)
(beq a0 a1 (L))          -> (beq (L) a0 a1)
(csrrw a0 mstatus a1)    -> (csrrw a0 a1 mstatus)
(amoadd.d.aqrl a0 a2 a1) -> (amoadd.d.aqrl a0 a1 a2)
```

它不编码、不布局、不绑地址。默认流不包含它。

## 与旧目录比对

旧目录 `../riscv-compiler` 保留为参照实现，canonical 是 GAS 顺序。
新目录默认是 native；同一个程序可以这样对照：

```scheme
;; 旧目录 / GAS
(sw t0 sp 8)
(beq a0 a1 (L))

;; 新目录 / native
(sw 8 sp t0)
(beq (L) a0 a1)
```

新目录的 GAS 流会先做同样的改写，所以两边最终字节应一致：

```racket
;; 旧目录
(run-flow target '(expand-data flatten expand-pseudo analyze dce relax bind-labels encode) seeds)

;; 新目录 / GAS
(run-flow target '(expand-data flatten gas-syntax analyze dce relax bind-labels encode) seeds)
```

## 文档

| 文档 | 内容 |
| --- | --- |
| [`SURFACE-SYNTAX.md`](SURFACE-SYNTAX.md) | native 表面语法 + 可选 GAS 方言 |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 分层地图与 stage |
| [`SEXP.md`](SEXP.md) | 层间 s-exp 类型速查 |
| [`gas-syntax/DESIGN.md`](gas-syntax/DESIGN.md) | GAS 可选重写层 |
| [`encode/syntax/DESIGN.md`](encode/syntax/DESIGN.md) | native plan / direct form |
| [`flow/DESIGN.md`](flow/DESIGN.md) | 构建流与硬边界 |
| `*/DESIGN.md` | 每层细节 |

## 跑

```bash
cd riscv-compiler-rebuild
racket test/rebuild-test.rkt
```

外部依赖：

- `../riscv-asm`：指令编码表
- `../riscv-help`：`li` / `la` / 远形式展开
