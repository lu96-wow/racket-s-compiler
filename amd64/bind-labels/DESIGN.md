# amd64 bind-labels

> measured layout -> bound layout：把 anchor 变成最终符号地址。

```racket
(bind-labels measured) ; -> bound-layout
```

产物：

```scheme
((phase bound)
 (segments ...)
 (anchors ...)
 (symbols (symbol chain segment offset address) ...)
 (requests ...)
 (problems ...))
```

## 职责

- 只接受 `phase = measured` 的布局。
- anchor -> `(symbol 链 段名 偏移 绝对地址)`。
- 用最终地址检查数据 `(value 宽度 值)` 是否放得进宽度，超出报
  `value-out-of-range` problem。
- 不改 item、不改 offset/size、不做松弛、不填 scratch、不做 reloc。

requests（例如 `needs-near` / `needs-far`）原样保留；没解决时由 encode 拒绝。
