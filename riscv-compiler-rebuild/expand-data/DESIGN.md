# expand-data 数据定义（`expand-data/expand.rkt`）

> 速览（功能 / s-exp / 设计理由）：[`../SEXP.md#expand-data`](../SEXP.md#expand-data)。
>
> 把"人写的数据"变成"核心 item"：宽度、值域、字符串、数组归这里；**端序不归这里**。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| 宽度 → 字节数（`b8/b16/b32/b64`） | 端序（属于 encode：变二进制那一步） |
| 整数值域检查 | 段 / 地址 / 偏移（属于 layout） |
| 字符串 → UTF-8 字节 | 代码 |
| 数组压缩 | 取地址求值（属于 encode） |
| 地址表达式 `(链)` / `(+ …)` / `(- …)` 原样透传（形状判定用 `sexp.rkt` 的 `address-expr?`） | 求值（属于 layout / encode）/ 真 reloc |
| `(module …)` 结构壳：**递归展开内容，壳原样留着** | 给 label 加模块前缀（属于 flatten） |

## 2. 输入 / 输出

```
rich item                        核心 item（输出的全部词汇）
─────────────────────────────    ───────────────────────────────────────
(b8 v) (b16 v) (b32 v) (b64 v)   (value 1|2|4|8 v)
(bN-array 总数 v...)             (fill 字节数 b) 或 n 条 (value 宽度 v)
(utf-string "…")                 (bytes …UTF-8…)
(utf-stringz "…")                (bytes …UTF-8… 0)
(label 链...)                     (label 链...)
(bytes b...)                     (bytes b...)
(fill 字节数 b)                   (fill 字节数 b)          ; 透传（幂等）
(pad n)                          (pad n)                 ; 透传（精确插 n 字节）
(align n)                        (align n)                 ; layout 会换算成 (pad n)
(b64 (链))                       (value 8 (链))
(b64 (+ 链 8))                   (value 8 (+ 链 8))
(b64 (- 链1 链2))                (value 8 (- 链1 链2))
```

旧壳 `(quote …)` / `(begin …)` 入口接受，出口一律 plain list。

**值**只有两种：

- 整数：`v ∈ [-2^(8N-1), 2^(8N))`（有符号或无符号放得下即可），按补码取低 8N 位；
- 地址表达式：整数 | `(链)` | `(+ 表达式 …)` | `(- 表达式 …)`。**不求值**——链的绝对地址要等
  layout 算完符号表，字节要等 encode。rich 和 core 同形，所以本层只透传。

## 3. API

| API | 输入 | 输出 |
| --- | --- | --- |
| `expand-data` | rich item 列表 | 核心 item 列表 |
| `expand-item` | 单条 rich item | 核心 item 列表（一条可以变多条） |
| `as-items` | 任意输入（含旧壳） | item 列表 |
| `width-form?` / `width-of` | 单条 item | 布尔 / 宽度（1/2/4/8） |

## 4. 规则

1. **宽度是数据，不是名字**：输出 `(value 宽度 值)`，所以下游不需要认识 `b16`。
   ```
   (b16 258) -> (value 2 258)      ; 不是 (bytes 2 1)：端序还没定
   ```
2. **地址表达式就是一个很小的算术语言**：整数 | `(链)` | `(+ a b …)` | `(- a b …)`。
   裸链就是"取这个 label 的地址"（和 `(la rd (f))` 一致）；`+`/`-` 至少两个操作数，可以嵌套。
   ```
   (b64 (d t))                 -> (value 8 (d t))
   (b64 (+ (d t) 8))           -> (value 8 (+ (d t) 8))
   (b64 (- (d t) 8))           -> (value 8 (- (d t) 8))
   ```
3. **数组压缩只看"与端序无关"**：宽度 1（一个元素就是一个字节）或值全 0 时压成一条
   `(fill 字节数 b)`；其余一个元素一条 `(value 宽度 v)`，因为字节序还没定、不能合并成 `bytes`。
   ```
   (b8-array 4096 0)      -> (fill 4096 0)
   (b32-array 1000000 0)  -> (fill 4000000 0)
   (b16-array 3 258)      -> (value 2 258) ×3
   (b8-array 5 1 2)       -> (value 1 1) (value 1 2) (fill 3 2)
   ```
4. **数组语义**：`(bN-array 总数 v...)` 前 k 个用 v1..vk，剩下的全用 vk。
5. `(fill 字节数 b)` 和 `(pad n)` 的名字**归 layout**（填充/对齐是它的模型），本层只透传；
   所以内部谓词叫 `fill-item?` / `pad-item?`，不导出。

## 5. 不归本层管

- 端序：固定 little；由 encode 落字节时使用。target 只含 XLEN / 扩展集。
- 段 / 偏移 / 地址：属于 layout。取地址的**求值**属于 encode。
- `segment` / `place` / 未知形式：直接 `error`（本层是数据入口）。
- `(module …)`：只当结构壳递归进去，**不解释它的名字** —— 前缀是 flatten 的事。

## 6. 测试（`expand-data/test.rkt`，75 条）

宽度/值域、地址表达式、字符串、数组压缩、`(module …)` 递归、幂等、错误路径、输出词汇封闭。

## 7. 已知缺口

- 表达式里的链必须是**绝对地址都已知**的 label（我们全静态，没问题）；将来做真 reloc 时，跨段的差值就不再是常量了。
- 没有 `.bss` / `.zero` / `.ascii` 这类指令式数据；`fill` 足够表达。
