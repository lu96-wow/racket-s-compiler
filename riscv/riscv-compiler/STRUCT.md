# struct：具名布局、静态数据与字段访问

> `struct` 是 **前端布局描述**，不是后端 layout 阶段。
> 它在 `layout` 之前展开成确定的 `value` / `align` / `pad` / native load/store。

## 1. 位置

```text
rich-data + program-items
  -> expand-struct
  -> expand-data
  -> flatten
  -> lower-code
  -> validate
  -> layout
  -> check
  -> bind-labels
  -> encode
```

`expand-struct` 做三件事：

1. 收集并计算 struct 布局
2. 展开静态数据实例
3. 展开字段访问、`sizeof`、`offsetof`

它不依赖最终地址，也不改 `layout` 的规则。

## 2. 定义

名字和 label 一样是链：

```scheme
(struct (point)
  (x b32)
  (y b32))

(struct (rect)
  (p point)
  (w b16)
  (h b16))
```

`point` 是 `(point)` 的单元素简写。

Struct 内部可以写字段和布局指令：

```scheme
(struct (aligned)
  (a b8)
  (align 8)     ; 内部对齐
  (b b32)
  (pad 3)       ; 显式空洞
  (c b16))
```

语法：

```scheme
(field-name type)
(align n)       ; n 必须是 2 的正整数次幂
(pad n)         ; n 是非负整数，插入 n 字节空洞
```

字段名必须是 symbol；同一 struct 内不能重名。
`align` / `pad` 是保留字，不能当字段名。

## 2.1 名字作用域

声明时的链会接在当前模块作用域后面：

```scheme
(module m
  (struct (point) (x b32) (y b32)))
```

完整名字是：

```scheme
(m point)
```

访问时先查当前模块，再查祖先模块，最后查根：

```scheme
(module m
  (struct (point) (x b8) (y b8))
  (label f)
  (struct-load t0 t1 point x)      ; 解析到 (m point)
  (struct-load t2 t3 (point) y))   ; 也解析到 (m point)
```

模块外可以用 `require` 后写本地名，也可以直接写完整链：

```scheme
(module a
  (provide point)
  (struct point (x b32) (y b32)))

(module b
  (require a)
  (struct rect (p point) (w b32)))   ; point -> (a point)

(struct-load t0 t1 (a point) x)     ; 完整链仍然可用
```

`require` 支持 `prefix-in` / `rename-in`；`provide` 支持 `rename-out` 和
re-export。struct 名字和 label 共用同一套模块子句，但各自是独立名字空间：
只 provide struct 不会把同名 label 也导出去。

根作用域也可以定义同名 struct，模块内会遮蔽它：

```scheme
(struct (point) (x b16))

(module m
  (struct (point) (x b8) (y b8))
  (label f)
  (struct-load t0 t1 point x))     ; (m point)，不是根 (point)
```

`struct-data`、`sizeof`、`offsetof`、`struct-load` 等所有引用 struct 的地方都接受
symbol 或链。

## 3. 类型

### 标量

```scheme
b8 b16 b32 b64
s8 s16 s32 s64
ptr
```

| 类型 | 大小 | 对齐 | load | store |
| --- | ---: | ---: | --- | --- |
| `b8` | 1 | 1 | `lbu` | `sb` |
| `s8` | 1 | 1 | `lb` | `sb` |
| `b16` | 2 | 2 | `lhu` | `sh` |
| `s16` | 2 | 2 | `lh` | `sh` |
| `b32` | 4 | 4 | RV64 `lwu` / RV32 `lw` | `sw` |
| `s32` | 4 | 4 | `lw` | `sw` |
| `b64` / `s64` | 8 | 8 | `ld` | `sd` |
| `ptr` | XLEN/8 | XLEN/8 | RV64 `ld` / RV32 `lw` | RV64 `sd` / RV32 `sw` |

`b64` / `s64` 在 RV32 上可以参与布局和静态数据，但字段访问会报错。

### 数组

```scheme
(array n type)
```

- `n` 是非负整数。
- 大小 = `n * sizeof(type)`
- 对齐 = `alignof(type)`

### 嵌套 struct

字段类型可以直接写另一个 struct 名：

```scheme
(struct rect
  (p point)
  (w b16)
  (h b16))
```

嵌套 struct 的大小和对齐来自它的定义。

## 4. 布局规则

v1 使用自然对齐：

1. 字段按声明顺序排列。
2. 每个字段向上对齐到自己的 align。
3. `(align n)` 把当前 offset 向上对齐到 n；它同时提高 struct 的 align。
4. `(pad n)` 插入 n 字节空洞，不改变 align。
5. struct 的 size 向上对齐到最大 align。
6. 空 struct：size = 0，align = 1。
7. 不支持 `packed`、bitfield、union。

例如：

```scheme
(struct point
  (x b32)
  (y b32))
```

```text
size  = 8
align = 4
x: offset 0, size 4, align 4
y: offset 4, size 4, align 4
```

```scheme
(struct rect
  (p point)
  (w b16)
  (h b16))
```

```text
size  = 12
align = 4
p: offset 0,  size 8, align 4
w: offset 8,  size 2, align 2
h: offset 10, size 2, align 2
```

内部对齐 / 空洞示例：

```scheme
(struct (aligned)
  (a b8)
  (align 8)
  (b b32)
  (pad 3)
  (c b16))
```

```text
size  = 24
align = 8
a: offset 0,  size 1,  align 1
b: offset 8,  size 4,  align 4
c: offset 16, size 2,  align 2

padding:
  align 8 at offset 1,  size 7
  pad 3   at offset 12, size 3
```

`c` 前面的 1 字节是字段自然对齐产生的；`padding` 只记录显式的
`align` / `pad` 指令。

## 5. 静态数据

```scheme
(label d p)
(struct-data point
  (x 1)
  (y 2))
```

展开成：

```scheme
(label d p)
(align 4)
(value 4 1)
(value 4 2)
```

### 5.1 标量字段

```scheme
(struct-data point
  (x 1)
  (y (+ (d base) 8)))
```

字段值可以是整数或地址表达式。

### 5.2 缺省字段

没写的字段补 0：

```scheme
(struct-data rect
  (w 3))
```

等价于：

```scheme
(struct-data rect
  (p (x 0) (y 0))
  (w 3)
  (h 0))
```

显式 `(pad n)` 和内部 `(align n)` 产生的空洞，在 data 段里都写 0。

### 5.3 嵌套 struct

```scheme
(struct-data rect
  (p (x 1) (y 2))
  (w 3)
  (h 4))
```

嵌套初始化写成字段对：

```scheme
(p (x 1) (y 2))
```

### 5.4 数组字段

数组字段的初始化可以写成：

```scheme
(a (array 1 2 3))
```

也可以直接写值：

```scheme
(a 1 2 3)
```

数组元素少于 `n` 时，尾部补 0。

数组元素是 struct 时：

```scheme
(struct arr
  (a (array 2 point)))

(struct-data arr
  (a (array ((x 1) (y 2))
            ((x 3) (y 4)))))
```

## 6. `sizeof` / `offsetof`

两者都是编译期整数，会直接替换成数字：

```scheme
(sizeof point)        ; 8
(offsetof point y)    ; 4
(sizeof rect)         ; 12
(offsetof rect w)     ; 8
```

可以放在普通操作数位置：

```scheme
(li t0 (sizeof rect))
(la-pcrel t1 (+ (d r) (offsetof rect w)))
```

`offsetof` v1 只支持直接字段，不支持 `(offsetof rect p x)` 这种路径。

## 7. 动态访问

### 短形式

```scheme
(struct-load rd base point y)        ; (lwu rd base 4)
(struct-store base point y rs)       ; (sw 4 base rs)
(struct-address dst base rect w)     ; (addi dst base 8)
```

短形式要求字段偏移在：

```text
[-2048, 2047]
```

超出范围会报错，要求使用 far 形式。

### far 形式

```scheme
(struct-load-far rd base rect w tmp)
(struct-store-far base rect w rs tmp)
(struct-address-far dst base rect w tmp)
```

展开：

```scheme
(struct-load-far rd base rect w tmp)
;; =>
(li tmp 8)
(add tmp base tmp)
(lhu rd tmp 0)

(struct-store-far base rect w rs tmp)
;; =>
(li tmp 8)
(add tmp base tmp)
(sh 0 tmp rs)

(struct-address-far dst base rect w tmp)
;; =>
(li tmp 8)
(add dst base tmp)
```

约束：

- `tmp` 不能是 `x0`
- `struct-load-far` 的 `tmp` 不能等于 `base`
- `struct-store-far` 的 `tmp` 不能等于 `base` 或 `rs`
- `struct-address-far` 的 `tmp` 不能等于 `base`

### 聚合字段

`struct-load` / `struct-store` 只接受标量字段。  
数组或嵌套 struct 字段用：

```scheme
(struct-address dst base rect p)
```

先算出字段地址，再自己决定加载什么。

## 8. 模块作用域

struct 名字按模块解析：

```scheme
(module m
  (struct point (x b32) (y b32))
  (label main)
  (struct-load t0 t1 point x))
```

最终元数据里的名字是完整链：

```scheme
(name (m point))
```

如果没有 `require`，模块外仍然可以写完整链：

```scheme
(struct-data (m point) (x 1) (y 2))
```

也可以按 label 的模块规则导入：

```scheme
(module a
  (provide point)
  (struct point (x b32) (y b32)))

(module b
  (require a)
  (struct rect (p point) (w b32)))
```

- `(provide point)` 导出本模块的 struct `(a point)`。
- `(provide *)` 导出本模块直接声明的 label 和 struct。
- `require` / `prefix-in` / `rename-in` / `rename-out` / re-export 与 label 规则一致。
- 同一个短名从两个 `require` 来，或 require 的名字和本地 struct 撞名，会报错。
- struct 和 label 是独立名字空间；`provide` 同时包含两者时两边各自导出。

跨**编译单元**（分离编译）时，把上一份 build 的 `structs` 和
`struct-provides` 分别作为 `extern-structs` / `extern-struct-provides` 输入。
之后既可以用完整链，也可以 `require`。

```scheme
;; A 编译出来的 build
(structs
  (struct-def (name (a point)) (size 8) (align 4) ...))

;; B 的输入（flow seed）
(extern-structs (structs
  (struct-def (name (a point)) (size 8) (align 4) ...)))

;; B 里直接用绝对名
(struct-load t0 t1 (a point) y)

;; 或者用 require / prefix-in / rename-in
(module b
  (require a)
  (struct-load t0 t1 point y))
```

`extern-structs` 接受：

- 上一份 `(build ...)`
- `(structs (struct-def ...) ...)`
- `(struct-def ...)` 列表

外部定义直接作为已算好的布局使用，不再重算 offset/size/align；相同的重复定义
会合并，同一个名字的两份不同定义或本单元与外部同名会报错。

`extern-struct-provides` 接受上一份 build 的 `(struct-provides ...)` 字段；
它让跨编译单元的 `require` / `prefix-in` / `rename-in` 和本单元内一样工作。
`label` 名字空间也有对称的 `label-provides` / `extern-label-provides`。

## 9. 最终导出

`build` 里会多一个 `structs` 字段：

```scheme
(build
  (link ...)
  (provides ...)
  (structs
    (struct-def
      (name (point))
      (size 8)
      (align 4)
      (fields
        (field (name x) (type b32) (offset 0) (size 4) (align 4))
        (field (name y) (type b32) (offset 4) (size 4) (align 4)))
      (padding))
    ...)
  (struct-provides
    (module ()
      (provide (point) (point))))
  (segment ...)
  ...)
```

有内部对齐 / 空洞时，`padding` 会记录：

```scheme
(padding
  (align (n 8) (offset 1) (size 7))
  (pad   (n 3) (offset 12) (size 3)))
```

`offset` 是指令开始时相对 struct 起点的位置，`size` 是插入的字节数。

字段类型保留：

- 标量：`b32` / `s16` / `ptr` …
- 数组：`(array 4 b32)`
- 嵌套 struct：`(struct-ref (m point))`

`structs` 按完整名字排序，保证产物稳定。

`struct-provides` 按模块记录“外部名 -> 绝对名”。下一份编译把它作为
`extern-struct-provides`，就能继续用 `require` / `prefix-in` / `rename-in`
绑定这些 struct。

## 10. 和原始数据定义的关系

`struct-data` 是 `rich-data` 的语法糖，展开后仍是：

```scheme
align / pad / value
```

所以 `layout`、`check`、`bind-labels`、`encode` 不需要认识 `struct`。

同理，动态访问展开后只留下：

```scheme
lw / lwu / ld / sw / sd / li / add / addi
```

`lower-code` 之后不会再有 `struct-load` / `sizeof` / `offsetof`。

## 11. v1 边界

不支持：

- bitfield
- union
- packed / 显式字段 offset
- 动态数组下标
- 多层 `offsetof` 路径
- 自动给裸 `b64` / `b32` 数据加自然对齐
- 自动把超范围 load/store 变成 far 形式
- `(reserve n)` 这种真正的地址洞；struct 里的 `(pad n)` 是零填充的 data 空洞

后端仍然遵守：

> 前端选形式，后端检查 + 编码；不自动 relaxation。

超范围时：

- `struct-load` / `struct-store` / `struct-address` 报错
- 前端改用对应的 `*-far` 形式
