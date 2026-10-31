# amd64 bind-labels

## 作用

`measured-layout -> bound-layout`：把 anchor 变成最终符号地址，并用最终地址做数据宽度检查。

```racket
(bind-labels measured) ; -> bound-layout
```

## 相关 s-exp

| 输入 | 输出 |
| --- | --- |
| `(phase measured)` | `(phase bound)` |
| `(anchors (anchor 链 段名 偏移) …)` | `(symbols (symbol 链 段名 偏移 绝对地址) …)` |
| `(value 宽度 值)` | 检查后原样保留，超出宽度报 problem |
| `(requests …)` / `(problems …)` | 原样传递 + 新增 value 检查问题 |

## 设计思路

- 只接受 `phase = measured` 的布局。
- `anchor` 的绝对地址 = `段 start + 段内偏移`。
- 符号表是链 → 绝对地址的唯一来源；encode 只读 symbols。
- 用最终地址求值 `value` 里的地址表达式，检查是否放得进宽度。
- requests 不消费；`needs-near` / `needs-far` 没解决时由 encode 拒绝。

## 边界

- 不改 item、不改 offset/size、不做松弛、不填 scratch、不做 reloc。
- 不检查指令范围、fallthrough、段重叠；这些属于 layout。
