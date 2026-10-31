# amd64 relax

> 只做 `jmp-short/jcc-short -> jmp-near/jcc-near`，只增不减。

```racket
(relax target program data-items layout-spec) ; -> measured-layout
```

每轮：

1. 把 `program -> layout items`，拼上 `data-items`。
2. 跑 `layout-items`。
3. 收集 `needs-near` request。
4. 按 request 里的扁平 item 下标把 short 换成 near。
5. 重跑 layout，直到没有 `needs-near`。

## 规则

- 只升级 short -> near，不降级。
- 不造 label、不拆块。
- `needs-far` 目前是 problem，不在这里处理。
- 对齐 padding 可以变小，但不要求 padding 单调。
- 最大轮数 64，防呆。

## 依赖

- `layout/forms.rkt` 的 `branch-form?` / `branch-range`。
- `layout/layout.rkt` 的 `needs-near` request。
