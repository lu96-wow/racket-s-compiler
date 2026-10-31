# amd64 expand-pseudo

> 只做拼写规范化和分支形式选择；不解析标签，不判断指令合法性。

## 输入输出

```racket
(rewrite-program items #:short-branches? [short? #f]) ; -> items
```

## 规则

| 源码 | 规范化 |
| --- | --- |
| `(jmp L)` | `(jmp-near L)` 或 `(jmp-short L)` |
| `(jcc cc L)` | `(jcc-near cc L)` 或 `(jcc-short cc L)` |
| `(call L)` | `(call-near L)` |
| `(je L)` `(jz L)` | `(jcc-... e L)` |
| `(jne L)` `(jnz L)` | `(jcc-... ne L)` |
| `(jc L)` | `(jcc-... b L)` |
| `(jnc L)` | `(jcc-... ae L)` |
| `(li rd v)` | 整数展开成 `(mov rd v)`；地址表达式展开成 RIP-relative `lea` |

`#:short-branches?` 默认 `#f`，即第一版 near-only。后续打开 short 时只需把参数
设为 `#t`，由 `relax` 负责升级。

操作数是值，不递归改写；label/data item 原样透传。
`rewrite-program` 之后 flow 会用 `pseudo-leftover?` 检查，伪指令不允许流入 layout/encode。
