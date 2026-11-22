# riscv-compiler

RISC-V s-expression 汇编器。

> **只认 `riscv-opcodes` native 顺序；不再提供 GAS 方言层。**

## 流水线

```text
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

输入是 canonical native；没有可选别名层。

```racket
'(expand-struct expand-data flatten analyze dce layout check bind-labels encode)
```

`layout` 只度量位置；`check` 只检查前端显式选择的跳转/地址形式，不改尺寸。

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
| [`SYNTAX.md`](SYNTAX.md) | native 表面语法 |
| [`RICH-DATA.md`](RICH-DATA.md) | rich-data 的完整数据语法与展开规则 |
| [`STRUCT.md`](STRUCT.md) | struct 布局、静态数据、字段访问与最终导出 |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 分层地图与 stage |
| [`IR.md`](IR.md) | 层间 IR 类型 |
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
- `../riscv-help`：`li` / `la` / 显式形式展开，以及统一的 `instruction-size`
