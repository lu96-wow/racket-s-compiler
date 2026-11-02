# expand-data（`expand.rkt`）

## 作用

把“人写的数据定义”变成核心数据 item：确定宽度、值域、UTF-8、数组压缩和地址字透传。

## 相关 s-exp

| 输入 | 输出 |
| --- | --- |
| `(b8 v)` / `(b16 v)` / `(b32 v)` / `(b64 v)` | `(value 宽度 值)` |
| `(bN-array n v…)` | `(fill n b)` 或若干 `(value w v)` |
| `(utf-string "…")` / `(utf-stringz "…")` | `(bytes …)` |
| `(label 链…)` / `(bytes …)` / `(fill n b)` / `(pad n)` / `(align n)` | 原样 |
| `(module …)` | 递归展开数据侧，壳保留 |
| 地址表达式 `(链)` / `(+ …)` / `(- …)` | 原样透传 |

## 设计思路

- 宽度和值域是数据定义问题，在本层解决。
- 端序不是本层问题：输出只交“宽度 + 值”，落字节在 encode。
- 数组只有在与端序无关时才压成 `(fill n b)`；否则保留逐元素 `(value w v)`。
- 地址表达式不求值：要等 layout 建 anchors、bind-labels 建 symbols。

## 边界

不处理段、偏移、地址求值、端序、重定位。
