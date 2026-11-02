# encode/syntax 指令语法拆分（`encode/syntax/*.rkt`）

> 编码层只回答一件事：**native s-exp 操作数怎么变成 riscv-asm 函数的参数**。
>
> GAS 顺序不在这里；它在可选的 `gas-syntax/` 前端层，先改写成 native。

## 1. 局部模块

| 文件 | 只负责 | 不负责 |
| --- | --- | --- |
| `suffix.rkt` | `.aq` / `.rl` / `.aqrl` 后缀 | 操作数、编码 |
| `operand.rkt` | 一个操作数值 → 数字（目前 GPR / 整数） | 操作数顺序、特殊形式 |
| `operand-kind.rkt` | `csr` / `zimm5` / `plain` 等 kind 的解释 | 顺序表、编码 |
| `csr-table.rkt` | CSR 名字 → 编号（从 csrs.csv 生成） | 语法、策略 |
| `csr32-table.rkt` | rv32 高位 CSR（从 csrs32.csv 生成，暂未接入） | 语法、策略 |
| `csr.rkt` | CSR 名字/编号 → 12 位值 | 其它操作数 |
| `native.rkt` | `instruction-info-operands` 顺序 → 函数参数 | GAS、特殊形式 |
| `direct.rkt` | 不能表达成位置表的特殊形式（`fence` / `fence.tso` / `c.nop`） | 普通指令、查表 |
| `plan.rkt` | 把 `native` / `direct` 组合成统一的 `syntax-plan` | 实际编码、具体操作数值 |
| `coverage.rkt` | native / GAS 的覆盖统计 | 修语法 |

## 2. 组合方式

```text
encode/insn.rkt
  → look up instruction-info
  → syntax/plan.rkt
        ├─ direct.rkt   fence / fence.tso / fence.i / c.nop
        └─ native.rkt   instruction-info-operands 顺序
  → syntax-plan-build (target)
        → operand-kind.rkt
              ├─ operand.rkt  (GPR / 整数)
              ├─ csr.rkt      (CSR 名字 / 编号)
              └─ zimm5        (5 位立即数)
        → riscv-asm generated instruction function
```

`insn.rkt` 不直接知道 `native` 和 `direct` 的差别，只使用统一的：

```racket
(syntax-plan source arities has-flags? build)
```

- `arities`：接受的操作数个数（如 `fence` 是 `(2 0)`）
- `has-flags?`：是否接受 `.aq` / `.rl`
- `build`：`target operands aq rl -> riscv-asm 函数参数`

## 3. native plan

`native.rkt` 从 `instruction-info-operands` 直接生成计划：

```text
sw      ("simm12" "rs1" "rs2")       -> (sw 8 sp t0)
beq     ("bimm12" "rs1" "rs2")       -> (beq (L) a0 a1)
ble     ("bimm12" "rs2" "rs1")       -> (ble (L) a1 a0)
csrrw   ("rd" "rs1" "csr")           -> (csrrw a0 a1 mstatus)
amoadd  ("rd" "rs1" "rs2" "aq" "rl") -> (amoadd.d.aqrl a0 a1 a2)
```

`aq` / `rl` 不占表面操作数，由助记符后缀提供，并在生成函数参数里插回原位。
`csr` / `zimm5` 是 operand-kind；其余 token 按 GPR/整数解释。

## 4. 规则

1. **native 是唯一编码方言**：编码层不判断 GAS。
2. **GAS 是可选前端层**：`gas-syntax/order-table.rkt` 只描述 GAS → native。
3. **`direct.rkt` 只放位置表表达不了的**：`fence` 的固定/保留字段、
   可变元数、特殊操作数解释。
4. **信息只有一份**：riscv-asm info 是编码事实的唯一来源；这里不复制
   `width` / `fixed-fields` / `raw-bindings`。
5. **coverage 分开统计**：native 缺项是 bug；GAS 缺项是扩展清单。

## 5. 当前覆盖

```text
native: 全部 instruction-info 都有 native plan，missing = 0
GAS:    可选方言，只覆盖 order-table.rkt 登记过的形状
```

GAS 的 655 条缺项不是“编码不会”，而是还没有 GAS 顺序表；主要缺口是
FPR / VREG、CSR / rm / vm、Zcmp / Zcmt / Zimop，以及大量普通形状。
需要支持时只加 `gas-syntax/order-table.rkt`，不要动编码层。

## 6. 测试

- `test/rebuild-test.rkt`：native 默认流、GAS 可选流、native 分支位置
- `syntax/coverage.rkt`：native / GAS 覆盖报告

## 7. 不归本层管

- `.aq` / `.rl` 的位域编码（riscv-asm 负责）
- 立即数范围、压缩寄存器约束（riscv-asm 负责）
- GAS 顺序（`gas-syntax/` 负责）
- 目标扩展/XLEN 选择（`target.rkt`）
- 寄存器使用、scratch（后续层）
