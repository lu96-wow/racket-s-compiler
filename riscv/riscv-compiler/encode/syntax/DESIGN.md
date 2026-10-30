# encode/syntax 指令语法拆分（`encode/syntax/*.rkt`）

> 这里只回答一件事：**s-exp 操作数怎么变成 riscv-asm 函数的参数**。
>
> 编码事实不在这里。指令名、宽度、固定字段、字段绑定、扩展归属仍然来自
> `riscv-asm/generated/.../info`。这一层是它的**语法适配器**。

## 1. 局部模块

| 文件 | 只负责 | 不负责 |
| --- | --- | --- |
| `suffix.rkt` | `.aq` / `.rl` / `.aqrl` 后缀 | 操作数、编码 |
| `operand.rkt` | 一个操作数值 → 数字（目前 GPR / 整数） | 操作数顺序、特殊形式 |
| `operand-kind.rkt` | `csr` / `zimm5` / `plain` 等 kind 的解释 | 顺序表、编码 |
| `csr-table.rkt` | CSR 名字 → 编号（从 csrs.csv 生成） | 语法、策略 |
| `csr32-table.rkt` | rv32 高位 CSR（从 csrs32.csv 生成，暂未接入） | 语法、策略 |
| `csr.rkt` | CSR 名字/编号 → 12 位值 | 其它操作数 |
| `order.rkt` | 普通指令的“s-exp 位置 → 函数参数位置”表 | 特殊形式、寄存器类扩展 |
| `direct.rkt` | 不能表达成位置表的特殊形式（`fence` / `fence.tso`） | 普通指令、查表 |
| `plan.rkt` | 把 `order` / `direct` 组合成统一的 `syntax-plan` | 实际编码、具体操作数值 |
| `coverage.rkt` | 从 riscv-asm info 统计哪些指令还没有语法计划 | 修语法 |

## 2. 组合方式

```text
encode/insn.rkt
  → look up instruction-info
  → syntax/plan.rkt
        ├─ direct.rkt   fence / fence.tso
        └─ order.rkt    普通形状
  → syntax-plan-build (target)
        → operand-kind.rkt
              ├─ operand.rkt  (GPR / 整数)
              ├─ csr.rkt      (CSR 名字 / 编号)
              └─ zimm5        (5 位立即数)
        → riscv-asm generated instruction function
```

`insn.rkt` 不直接知道 `order` 和 `direct` 的差别，只使用统一的：

```racket
(syntax-plan source arities has-flags? build)
```

- `arities`：接受的操作数个数（如 `fence` 是 `(2 0)`）
- `has-flags?`：是否接受 `.aq` / `.rl`
- `build`：`target operands aq rl -> riscv-asm 函数参数`

## 3. 规则

1. **一个模块只有一个知识**：后缀、顺序、特殊形式、覆盖检查分开。
2. **不猜默认值**：`order.rkt` 没登记的形状直接报 `no operand syntax`，
   不自动用 `(0 1 2 ...)` 兜底。
3. **`direct.rkt` 只放位置表表达不了的**：`fence` 的固定/保留字段、
   可变元数、特殊操作数解释。
4. **信息只有一份**：riscv-asm info 是编码事实的唯一来源；这里不复制
   `width` / `fixed-fields` / `raw-bindings`。
5. **新扩展先看 coverage**：`syntax-coverage` 直接列出没有计划的
   `(扩展 指令名 operands)`，不靠手写清单。

## 4. 怎么加东西

### 加一个普通形状

只改 `order.rkt`：

```racket
"rd rs1 csr" '(0 2 1)   ; 例：源码 csr 在第三个位置
```

### 加一个特殊形式

只改 `direct.rkt`：

```racket
'fence.i (direct-plan '(0) (lambda (_) '()))
```

### 加一种操作数类型

改 `operand.rkt`，并在需要时增加局部的 kind 表：

```text
GPR / FPR / VREG / CSR / rm / vm / nf / rlist / ...
```

寄存器类、CSR 表、舍入模式表都应放在这一层的局部模块里，
不要塞进 `insn.rkt` 或 `order.rkt`。

### 加一个扩展

1. 在 `target.rkt` 的 target profile 里打开
2. 跑 `syntax-coverage`
3. 按缺项补 `order.rkt` / `direct.rkt` / `operand-kind.rkt`

## 5. 当前覆盖

```text
当前 target 的扩展：missing = 0
rv_zicsr / rv_zifencei：missing = 0
riscv-asm 全部 110 个扩展：1232 条 info，已覆盖 591，缺 641
```

当前切片已完成：

```text
(csrrw a0 mstatus a1)
(csrr  a0 mstatus)
(csrw  mstatus a1)
(csrrwi a0 mstatus 3)
(csrwi  mstatus 3)
(fence.i)
```

这 655 条不是“编码不会”，而是**还没有 s-exp 语法**；主要缺口是
FPR / VREG、CSR / rm / vm、Zcmp / Zcmt / Zimop，以及大量普通形状。

## 6. 测试

- `encode/test.rkt`：现有 target 的全部指令字与语法路径
- `syntax/coverage.rkt`：扩展覆盖报告
- 外部 `riscv-compiler-test/encode-test.rkt`：黑盒编码契约

## 7. 不归本层管

- `.aq` / `.rl` 的位域编码（riscv-asm 负责）
- 立即数范围、压缩寄存器约束（riscv-asm 负责）
- 目标扩展/XLEN 选择（`target.rkt` / 未来的 target profile）
- 寄存器使用、scratch（后续层）
