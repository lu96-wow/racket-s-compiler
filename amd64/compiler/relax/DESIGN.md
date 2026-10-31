# amd64 relax

## 作用

只做 `jmp-short/jcc-short -> jmp-near/jcc-near`，只增不减。

```racket
(relax target program data-items layout-spec) ; -> measured-layout
```

## 相关 s-exp

| 输入 | 输出 |
| --- | --- |
| `program`（blocks + flows） | `measured-layout` |
| `(needs-near (code 块下标 项下标) 段名 offset item disp)` | 同一 layout，但对应 item 已升级 |
| `(jmp-short L)` / `(jcc-short cc L)` | `(jmp-near L)` / `(jcc-near cc L)` |

## 设计思路

每轮：

1. 跑 `layout-program`。
2. 收集 `needs-near` request。
3. 按 request 里的 `(code 块下标 项下标)` 精确替换 program 里的 short 分支。
4. 重跑 layout，直到没有 `needs-near`。

规则：

- 只升级 short -> near，不降级。
- 不造 label、不拆块、不改 CFG。
- 只改 program 的 block item；data 不变。
- `needs-far` 留在 requests 里，由 encode 拒绝；far form 还没实现。
- 最大轮数 64，防呆。

## 边界

- 不填 scratch、不生成 trampoline、不处理 `li`/RIP 范围。
- 不做布局、不绑地址、不编码。
- 不处理 `layout-flat-items` 的 `(flat …)` origin。
