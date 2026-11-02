# expand-pseudo（`rewrite.rkt` `table*.rkt`）

## 作用

可选的便利别名层。把 `riscv-opcodes` 没有的别名展开成 native 指令。

默认流不包含本层；需要别名时再把它加进 flow。

## 相关 s-exp

| 输入（native 顺序） | 输出 |
| --- | --- |
| `(move rd rs)` | `(add rd rs x0)` |
| `(load-8 rd rs1 off)` | `(lbu rd rs1 off)` |
| `(store-8 off rs1 rs2)` | `(sb off rs1 rs2)` |
| `(branch-le L rs1 rs2)` | `(bge L rs2 rs1)` |
| 不认识的 form | 原样透传 |

`riscv-opcodes` 已经定义的伪指令（`mv` / `ble` / `nop` 等）不需要
在这里再写一遍，native 编码器可以直接处理。

## 设计思路

- 只做拼写/形状替换，不改变控制流语义。
- 模板已经是 `instruction-info-operands` 的 native 顺序。
- GAS 顺序不在这里；它在 `gas-syntax/`。
- 形状不匹配就透传；真正的合法性统一留给 encode（`riscv-asm`）。

## 边界

- 不判断结果是否合法、不算尺寸、不处理 `li` / `la` 的最终地址。
- 不负责 GAS 方言。
