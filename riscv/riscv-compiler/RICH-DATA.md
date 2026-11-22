# rich-data 语法

> `rich-data` 是 `expand-data` 的输入，也就是“人写的数据定义”。
> 它在进入 `layout` 之前被展开成核心数据 item：
>
> ```text
> rich-data -> expand-data -> data-items
> ```
>
> 本文只描述数据侧。代码、段、`place`、地址绑定见 [`SYNTAX.md`](SYNTAX.md)。

## 1. 入口形状

`expand-data` 接受普通 item 列表，也接受旧壳：

```scheme
'((label d table)
  (b8 1)
  (utf-stringz "hi"))
```

```scheme
'(quote ((label d table) (b8 1)))
'(begin (label d table) (b8 1))
```

出口一律是 plain list，不会把 `quote` / `begin` 继续传下去。

## 2. 基本数据形式

### 2.1 定宽整数

```scheme
(b8  v)
(b16 v)
(b32 v)
(b64 v)
```

宽度：

| 形式 | 宽度 | 输出 |
| --- | ---: | --- |
| `(b8 v)` | 1 | `(value 1 v)` |
| `(b16 v)` | 2 | `(value 2 v)` |
| `(b32 v)` | 4 | `(value 4 v)` |
| `(b64 v)` | 8 | `(value 8 v)` |

值域：

```text
v ∈ [-2^(8w-1), 2^(8w))
```

也就是同时接受“有符号下界”和“无符号上界”：

```scheme
(b8 255)     ; 合法
(b8 -128)    ; 合法
(b8 256)     ; 错误
(b8 -129)    ; 错误
```

整数按补码取低 `8w` 位。端序不在 `expand-data` 决定；`(value w v)` 只携带
宽度和值，实际落字节在 `encode`。

### 2.2 定宽整数的地址表达式

`bN` 的值也可以是一个地址表达式：

```scheme
(b64 (d table))
(b64 (+ (d table) 8))
(b32 (- (d end) (d start)))
```

`expand-data` 只检查形状，不求值：

```scheme
(b64 (d table))          -> (value 8 (d table))
(b64 (+ (d table) 8))    -> (value 8 (+ (d table) 8))
```

地址表达式在后面的 `check` / `bind-labels` / `encode` 阶段处理。

### 2.3 字符串

```scheme
(utf-string  "abc")
(utf-stringz "hi")
```

- `utf-string`：按 UTF-8 编码，不加结尾。
- `utf-stringz`：按 UTF-8 编码，末尾补一个 `0` 字节。
- 参数必须恰好是一个字符串。

例子：

```scheme
(utf-string "abc")    -> (bytes 97 98 99)
(utf-stringz "hi")    -> (bytes 104 105 0)
(utf-string "")       -> (bytes)
(utf-stringz "")      -> (bytes 0)
```

### 2.4 对齐

```scheme
(align 8)
(align 16)
```

`n` 必须是正整数。`align` 是请求，不是固定字节数：

- `code` / `data` 段里由 `layout` 转成 `(pad n)`
- `hole` 段里由 `layout` 转成 `(reserve n)`

## 3. 数组

```scheme
(b8-array  n v ...)
(b16-array n v ...)
(b32-array n v ...)
(b64-array n v ...)
```

`n` 是元素个数，不是字节数。

### 3.1 基本语义

- `n` 必须是非负整数。
- `n = 0`：不允许有初值，输出空字节：

```scheme
(b8-array 0) -> (bytes)
```

- `n > 0`：至少给一个初值。
- 初值个数不能超过 `n`。
- 前 `k` 个位置用给出的 `v1..vk`，剩余位置全部重复最后一个 `vk`。

例子：

```scheme
(b32-array 4 1 2)   ; 1 2 2 2
(b8-array  5 1 2)   ; 1 2 2 2 2
(b16-array 3 258)   ; 258 258 258
```

### 3.2 数组里的地址表达式

数组初值可以是地址表达式：

```scheme
(b8-array 3 (d table))
(b64-array 2 (f) (+ (g) 8))
```

地址元素不会被压缩成 `fill`；每个元素各产生一条 `(value w expr)`。

```scheme
(b8-array 3 (t))
-> ((value 1 (t)) (value 1 (t)) (value 1 (t)))
```

### 3.3 什么时候压缩成 `fill`

`expand-data` 只在**与端序无关**时把数组尾部压缩成 `fill`：

- 宽度是 1；或
- 所有被压缩的值都是 `0`。

例子：

```scheme
(b8-array 5 0)       -> (fill 5 0)
(b8-array 5 1 2)     -> (value 1 1) (value 1 2) (fill 3 2)
(b32-array 4 0)      -> (fill 16 0)
(b32-array 4 1 2)    -> (value 4 1) (value 4 2) (value 4 2) (value 4 2)
```

为什么 `b32-array 4 1 2` 不能直接写成 `bytes`：端序还没定，不能把 32-bit
值提前摊成字节序列。

## 4. 核心数据 item 透传

`expand-data` 也接受已经展开好的核心形式，并原样透传：

```scheme
(label chain ...)
(bytes b ...)
(fill n b)
(pad n)
(value w expr)
(align n)
```

例子：

```scheme
(label d table)
(bytes 1 2 255)
(fill 8 0)
(pad 4)
(value 8 (main))
(align 8)
```

`value` 的值可以是整数，也可以是地址表达式。

注意：`reserve` **不是** rich 形式。它只属于核心数据 item，并且只能出现在
`hole` 段；需要时直接把 `(reserve n)` 作为 `data-items` 输入，而不是放进
`rich-data`。

> 结构体语法（`struct` / `struct-data` / `struct-load`）见 [`STRUCT.md`](STRUCT.md)。

## 5. module 壳

`expand-data` 会递归展开 `module` 里的数据，但保留 `module` 壳：

```scheme
(module m
  (provide t)
  (require d)
  (label d t)
  (b16 258))
```

输出：

```scheme
(module m
  (provide t)
  (require d)
  (label d t)
  (value 2 258))
```

`provide` / `require` 的语义属于 `flatten`，不属于 `expand-data`。
`expand-data` 只递归数据 item，保留模块壳和这些子句。

## 6. 输出词汇

`expand-data` 的输出只会出现这些头：

```scheme
label
bytes
fill
pad
value
align
module
```

不会出现：

```scheme
b8 b16 b32 b64
b8-array b16-array b32-array b64-array
utf-string utf-stringz
```

这些 rich 名字在 `expand-data` 之后消失。

## 7. 幂等性

核心形式可以再次喂给 `expand-data`，输出不变：

```scheme
(expand-data '((label d t) (b16 258) (utf-stringz "hi")))
;; => ((label d t) (value 2 258) (bytes 104 105 0))

(expand-data '((label d t) (value 2 258) (bytes 104 105 0)))
;; => ((label d t) (value 2 258) (bytes 104 105 0))
```

`module` 壳会继续递归展开，但不会丢失壳。

## 8. 错误情况

常见错误：

```scheme
(b8 256)                 ; 值超出 b8
(b8 -129)                ; 值低于 b8
(b32 1.5)                ; 不是整数
(b32 "x")                ; 不是整数/地址表达式
(utf-string 42)          ; 参数不是字符串
(utf-string "a" "b")     ; 字符串个数不对
(b8-array -1 0)          ; 数组大小非法
(b8-array 3)             ; n > 0 但没有初值
(b8-array 2 1 2 3)       ; 初值多于数组大小
(b8-array 0 1)           ; 0 大小不能有初值
(b64 (+ (d t)))          ; + 至少要两个操作数
(b64 (* (d t) 8))        ; 未知算术头
(reserve 8)              ; rich 层不接受 reserve
(unknown-form 1)         ; 未知数据形式
```

数组大小是 `0` 时输出 `(bytes)`，不会产生 `fill` 或 `value`。

## 9. 和后续层的关系

```text
rich-data
  -> expand-data   ; 宽度 / 值域 / UTF-8 / 数组压缩
  -> data-items
  -> layout        ; 段、偏移、align -> pad / reserve
  -> check         ; 地址表达式里的链是否存在
  -> bind-labels   ; value 的值域 / 最终宽度
  -> encode        ; little-endian 字节
```

`expand-data` 不做：

- 段归属
- 偏移计算
- 地址求值
- 端序
- 重定位
- `reserve` 的 rich 语法

这些分别属于 `layout` / `check` / `bind-labels` / `encode`。
