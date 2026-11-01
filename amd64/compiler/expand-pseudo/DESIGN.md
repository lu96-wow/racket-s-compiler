# amd64 expand-pseudo

## 作用

把源码写法规范化成 `insn.rkt` 认识的真实 form。

```racket
(rewrite-program items #:short-transfers? [short? #f]) ; -> items
```

## 相关 s-exp

| 输入 | 输出 |
| --- | --- |
| `(jmp L)` | `(jmp-near L)` 或 `(jmp-short L)` |
| `(jcc cc L)` | `(jcc-near cc L)` 或 `(jcc-short cc L)` |
| `(call L)` | `(call-near L)` |
| `(je L)` / `(jz L)` / `(jne L)` … | `(jcc-… e L)` 等规范条件码 |
| `(li rd 整数)` | `(mov rd 整数)` |
| `(li rd 地址表达式)` | `(lea rd (b64 (base rip) (disp 地址表达式)))` |
| 其它 item / label / 数据 | 原样透传 |

## 设计思路

- 只做拼写规范化和分支形式选择。
- 操作数是值，不递归改写。
- `jmp`/`jcc` 的 short/near 选择由参数决定；默认 near-only，flow 里用 short 起步，
  交给 relax 升级。
- 条件码别名、`li`、`jmp/jcc`、`call` 的 form 策略来自
  `../../amd64-help/main.rkt`；本层只做遍历和调用，不复制策略表。
- `li` 的地址表达式统一变成 RIP-relative `lea`；是否可达由 layout 检查。
- `pseudo-leftover?` 在 flow 里做最后检查，伪指令不能流入 layout/encode。

## 边界

- 不解析标签、不判断指令合法性、不算尺寸。
- 不处理段/地址/编码。
- 不处理 Loko 旧写法；那属于 `loko-compat`。
