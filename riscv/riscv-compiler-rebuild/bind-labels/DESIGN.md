# bind-labels（`bind.rkt`）

## 作用

把 measured-layout 的 `anchors` 落到绝对地址，产出 bound-layout。

核心公式：

```racket
绝对地址 = segment.start + anchor.offset
```

## 相关 s-exp

输入 measured-layout：

```racket
((phase measured)
 (segments …)
 (anchors (anchor 链 段名 偏移) …)
 (requests …)
 (problems …))
```

输出 bound-layout：

```racket
((phase bound)
 (segments …)
 (anchors …)
 (symbols (symbol 链 段名 偏移 绝对地址) …)
 (requests …)
 (problems …))
```

新增检查：

- `(value 宽度 值)` 的值是否放得进宽度
- `segment-overflow`

## 设计思路

- `layout`/`relax` 只该管“位置”；`offset → address` 是一个独立的收尾。
- 绝对地址只在 bound-layout 出现，`encode` 就不可能误用松弛中间值。
- `value` 宽度和段容量只有最终地址/最终尺寸才知道，所以放在这里。
- 幂等；不改 item / offset / size；不解决 requests。

## 边界

不松弛、不填 scratch、不补跳、不重定位/链接。
`needs-far` / `scratch-hole` / `la-too-far` 原样保留，`encode` 要求 requests/problems 都空。

未来寄存器层应插在 `relax` 之后、`bind-labels` 之前；凡会改尺寸的 pass 也必须在它之前收敛。
