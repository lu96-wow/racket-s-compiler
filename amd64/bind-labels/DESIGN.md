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
 (problems ...))
```

只做 anchor -> 地址，不改 item，不做 reloc。
