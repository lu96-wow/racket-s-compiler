# registers（`registers.rkt`）

## 作用

记录寄存器事实：名字、class、宽度、编码编号、REX 属性和 high-byte 限制。
只放事实，不做寄存器分配。

## 数据模型

```racket
(struct reg (name width index rex8? high8? class) #:transparent)
```

class：

```text
gpr      通用寄存器
xmm      SSE 寄存器
control  控制寄存器（cr0/cr2/cr3/cr4/cr8）
debug    调试寄存器（dr0..dr7）
```

## 相关 s-exp / 函数

| 名字 | 作用 |
| --- | --- |
| `lookup-register name` | 名字 -> reg 记录 |
| `register-name? name` | 名字是否是已知寄存器 |
| `reg? x` | 是否是 reg 记录 |
| `gpr-register? r` / `xmm-register? r` | class 判定 |
| `reg-name` / `reg-width` / `reg-index` | 编码事实 |
| `reg-rex8?` / `reg-high8?` | 8 位寄存器是否要求/禁止 REX |

## 设计思路

- GPR、XMM、control、debug 共用一张名字表，编码器按 class 选择路径。
- `parse-reg` / `parse-rm` 只接受 GPR；`parse-xmm` / `parse-xmm-or-mem` 只接受 XMM。
- `mov cr/dr` 在 `insn.rkt` 里单独编码，不把控制寄存器混进普通 ModR/M 路径。
- high-byte 寄存器（ah/ch/dh/bh）不能和 REX 同时出现，`make-rex` 负责检查。

## 边界

不分配寄存器、不决定 scratch、不处理 ABI/调用约定。
