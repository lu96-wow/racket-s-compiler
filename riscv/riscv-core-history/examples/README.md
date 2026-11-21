# examples

纯数据示例；`test/` 直接 `require` 这些绑定。

| 文件 | 内容 |
| --- | --- |
| `minimal.rkt` | 一个 block、一个 `return`，最小 virtual / allocation / machine 三态 |
| `branch.rkt` | 一个条件分支、一个 `jump`，用来验证 CFG 和 layout |
| `allocation.rkt` | 寄存器分配、slot 分配、scratch |
| `stack-local.rkt` | stack-first：`(address-taken)` + 显式 `addr` / `load` / `store` + frame |
| `module.rkt` | module / provide / require 源码形状与解析后形状 |
| `asm.rkt` | 纯汇编 `raw` 与内嵌 `asm` |
| `data.rkt` | 全局 data 段：align / value / bytes / fill |

约定：

- 所有条目都是 proper list。
- 虚拟寄存器是 `($ name)`。
- 物理寄存器是 `(native xN)`。
- 不出现 C ABI 名字。
- 不出现 `unit` / `uint` / `$var` / dotted pair。
