# analyze（`insn.rkt` `cfg.rkt` `analyze.rkt`）

## 作用

控制流分析：把线性 item 切成基本块，并给出每个块的后继、顺序下落和 root 标记。

## 相关 s-exp

| 输入 | 输出 |
| --- | --- |
| 扁平程序 item 列表 | `(struct program blocks flows)` |
| `data-items`（只用于找“地址被取过”的链） | `program` |
| `(label 链…)` / 控制转移 | 块边界、`succ`、`fallthrough` |
| 数据里的地址表达式 `(链)` / `(+ …)` / `(- …)` | root 标记 |

`block` 是 `(block <头链列表> item…)`。
`flow` 是 `(flow (succ id…) (fallthrough id|#f) (root? bool))`。

## 设计思路

- 块边界只由控制流决定：程序开头、跳转目标 label、`ends-block?` 指令之后。
- 非目标 label 只是块内位置标记，不切块。
- `succ` 服务可达性，`fallthrough` 服务物理布局；两者分开。
- 数据 item 不进 CFG，只贡献 root：数据里存地址 = 把入口交给外部。

## 边界

不改程序、不判指令合法性、不算尺寸/地址、不删块。
