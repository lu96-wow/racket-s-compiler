# raw：纯汇编单元

`raw` 是 machine 层的封闭代码单元，不经过 virtual IR / allocation / materialize /
call-lower。

```scheme
(raw (start)
  (label (loop))
  (addi (native x10) (native x0) 1)
  (bne (loop) (native x10) (native x11))
  (j (start)))
```

`raw` 的名字是全局链，也是该单元的入口 label。module 的 `provide` / `require`
规则见 [`MODULES.md`](MODULES.md)。

## 1. 形状

```scheme
(raw chain item ...)
```

- `chain` 是 raw 单元入口的全局名。
- body 只能包含旧 machine item：
  - `(label chain ...)`
  - `(j chain)`
  - `(beq|bne|blt|bge|bltu|bgeu chain operand operand)`
  - `(jal (native xN) chain)`
  - 其它 native 指令：`(mnemonic operand ...)`
- 所有非 label item 固定按 4 字节计。
- 不在这里做 `li` / `la` / 远跳展开；这些是 raw 作者显式写出的机器指令。

## 2. label

- raw 名字在偏移 0 处隐式定义一个全局 label。
- `(label chain ...)` 在当前偏移定义全局 label，不占字节。
- raw label 是模块作用域的全局名，参与 `provide` / `require` / rename / prefix。
- 同一个 raw 单元内 label 不能重复；也不能和 raw 名字重复。
- raw label 不能和 func / data / data label 重名。

## 3. 控制转移

目标写在前面，和现有 native 习惯一致：

```scheme
(j (done))
(bne (loop) (native x10) (native x11))
(jal (native x1) (f))
```

- `(j target)` -> `jal x0, target`
- 条件分支：`(bne target rs1 rs2)` 等
- `jal`：`(jal link target)`，target 在第二个操作数
- target 必须是**同一个 raw 单元**里的 label
- 不支持跨 raw / func 的控制转移
- 第一版不做远跳 relaxation；目标超出指令范围时由 encode 报错

## 4. 操作数

- 物理寄存器：`(native xN)`，只允许 `x0..x31`
- 立即数：整数
- 不出现 `($ ...)` / `(global ...)` / `(frame-slot n)` / `(scratch ...)`
- native 指令里的操作数只能是整数或 native 寄存器；label 只出现在控制转移位置

## 5. program layout

- 所有 func 先排，随后 raw 单元按输入顺序，最后 data。
- raw 单元内部固定 4 字节；不需要函数 frame。
- raw 名字和内部 label 进入 program 全局地址表。
- `addr(global raw-label)` 和 data 地址初值可以引用 raw label。
- raw 单元不能作为 `call-target` 目标。
- program layout 不做 raw 内部远跳 relaxation；encode 只编码固定形式。

## 6. encode

- raw section 的 labels 是段内偏移。
- `(label ...)` 0 字节。
- `(j ...)` 写成 `(jal (native x0) target)`。
- 条件分支 / `jal` 用 section 内 label 偏移编码。
- 其它 native 指令直接编码，尺寸必须是 4。
- raw section 之间不共享 label 偏移；跨 section 目标在 raw 校验时报错。

## 7. 与 inline asm 的区别

| | raw | inline asm |
| --- | --- | --- |
| 位置 | 顶层代码单元 | 函数里的 op |
| 输入 | 无 | inputs / outputs |
| 输出 | 无 | outputs |
| 名字 | 全局 label | asm.code 内局部 label |
| CFG | 自己的 label / 分支 | 封闭代码块，不接外层 CFG |
| 经过 virtual IR | 否 | 是 |

## 8. 暂不支持

- raw 内部远跳 relaxation / island；
- 跨 raw / func 的跳转；
- raw 内部 `li` / `la` / 其他 pseudo 自动展开；
- raw 与 data 共用一个 section；
- RVC；
- 外部符号 / relocation。
