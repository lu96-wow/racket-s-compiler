# amd64 relax

> 只做 `jmp-short/jcc-short -> jmp-near/jcc-near`，只增不减。

```racket
(relax target program data-items layout-spec) ; -> measured-layout
```

每轮：

1. 跑 `layout-program`。
2. 收集 `needs-near` request。
3. 按 request 里的 `(code 块下标 项下标)` 精确替换 program 里的 short 分支。
4. 重跑 layout，直到没有 `needs-near`。

## 规则

- 只升级 short -> near，不降级。
- 不造 label、不拆块、不改 CFG。
- 只改 program 的 block item；data 不变。
- `needs-far` 目前留在 requests 里，由 encode 拒绝；far form 还没实现。
- 最大轮数 64，防呆。

## 依赖

- `layout/layout.rkt` 的 `needs-near` request 和 `(code ...)` origin。
- `analyze/analyze.rkt` 的 program/block 构造器。
