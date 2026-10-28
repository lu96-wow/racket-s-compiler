> **在 F-asm 中**：Scheme 可见值统一用 `value`（tagged 64-bit）；
> `b8..b64` / `pb*` 只用于 runtime 内部。见 `FASM.md`。

# 表示类型（representation types）

> 这不是源码类型系统，而是后端需要的“表示类型”：
> **宽度、对齐、是否指针、是否是带标签的 Lisp 值。**
> 采用 A 方案：类型直接标在 frame slot 上。

---

## 1. 类型语法

```text
T ::= b8 | b16 | b32 | b64      ; 精确位宽；signed/unsigned 由操作决定
    | pb8 | pb16 | pb32 | pb64  ; 指向对应宽度的指针（指针本身 64 位）
    | (ptr T)                   ; 通用指针写法
    | (struct S)                ; 结构体（按值）
    | (array T n)               ; 数组（按值）
    | value                     ; 带标签的 64 位 Lisp 值
    | bool | nil                ; value 的子集，方便标注
```

规则：

- `b8/b16/b32/b64` 只表示**存储宽度**，不表示符号。
  `add/sub/slt` 等操作决定 signed/unsigned。
- `pb8..pb64` 是“指向该宽度的指针”；指针本身在 RV64 上是 8 字节。
- `(struct S)` 是结构体值；在 frame slot 里必须写成 `(ptr (struct S))`，
  因为一个 slot 只有一个机器字。
- `value` 是带标签的 Lisp 值；`#t/#f/'nil` 属于这一层。

---

## 2. slot 直接标类型（A 方案）

```racket
(frame
  (base fp)
  (link fp)
  (slots
    (slot0 (kind arg)   (repr b64))
    (slot1 (kind local) (repr (ptr (struct point))))
    (slot2 (kind spill) (repr value))
    (slot3 (kind captured) (repr bool))))
```

- `(repr T)` 可省略，默认 `b64`。
- `(kind ...)` 仍是**存储类别**（arg/local/spill/captured/saved/outgoing），
  不是类型。
- 第一版限制：slot 必须是**一个字**。
  `(repr (struct point))`、`(repr (array b8 16))` 会被拒绝；
  要存结构体就用 `(repr (ptr (struct point)))`。

---

## 3. 结构体布局

```racket
(struct point
  (field x b8)
  (field y b64))
```

布局规则：

- 字段按声明顺序排列。
- `b8` 对齐 1，`b16` 对齐 2，`b32` 对齐 4，`b64`/指针/`value` 对齐 8。
- 结构体对齐 = 字段最大对齐；大小向上取整到该对齐。

上面的 `point`：

```text
x : offset 0  (b8)
y : offset 8  (b64, 因为要 8 对齐)
size  = 16
align = 8
```

第一版字段不能按值嵌套 `struct`/`array`；可以用 `(ptr (struct ...))`。
字段访问指令（`field-ref`/`field-set`）还没接，布局函数已经有了。

---

## 4. 字面值：`#t #f 'nil`

`value` 是 64 位带标签值，低 3 位 tag：

```text
000 fixnum
001 char
010 cons pointer
011 symbol pointer
100 string pointer
101 vector pointer
110 closure pointer
111 special
```

special 的内部编码是 `(code << 3) | 7`：

| 字面值 | 编码 |
|---|---:|
| `#f` | 7 |
| `#t` | 15 |
| `'nil` | 23 |
| `eof` | 31 |

物化用 `const`：

```racket
(const v0 #t)     ; -> (addi v0 x0 15)
(const v0 #f)     ; -> (addi v0 x0 7)
(const v0 'nil)   ; -> (addi v0 x0 23)
(const v0 42)     ; -> (addi v0 x0 42)   ; 原始 b64，不是 tagged fixnum
```

当前只接受 signed 12-bit 立即数；更大的整数以后用 `lui/addi` 展开。

注意：`#f` 和整数 `7` 在机器字上相同，但 `literal-repr` 不同：

```text
#f  -> bool
nil -> nil
42  -> b64
```

是否把它们混用，目前由程序员/上层决定；这一层还不做赋值类型检查。

---

## 5. 现在检查了什么，没检查什么

**已检查：**

- `repr?` 语法：`b8..b64`、`pb8..pb64`、`(ptr T)`、`(struct S)`、`(array T n)`、`value/bool/nil`
- slot 的 `(repr T)` 必须是单字：struct/array 直接存会被拒绝
- struct 字段必须是单字或指针，布局/大小/对齐可计算
- `const` 字面值有固定编码，且必须放进 12 位立即数

**还没检查：**

- vreg 的类型传播：`add` 的两个操作数是否都是 `b64`，结果是什么
- `env-set`/`env-ref` 的 slot 类型与 vreg 是否匹配
- `call` 的签名/arity
- `return` 的返回值形状
- 指针目标类型的兼容性
- GC 的 pointer map（`roots` 还没用 slot repr 生成）

也就是说：**类型语言已经能写、能验证布局，但还没有变成类型检查器。**
下一步是给 vreg 加一张 `(types ...)` 表，做最小传播：

```text
env-ref dst (heap 0 i)  : repr(slot i) -> type(dst)
addi dst src imm        : type(src)=b64 -> type(dst)=b64
add dst a b             : a,b : b64 -> dst : b64
call f ...              : 查 f 的签名
return (v)              : 与函数返回类型匹配
```

---

## 6. 和现有文档的关系

- `frame.rkt`：`slot-decl-repr` 读取/默认 `(repr T)`。
- `repr.rkt`：类型语法、宽度/对齐、struct 布局、字面值编码、`const` 形式。
- `literal-lower.rkt`：`const` -> `addi`。
- `asm.rkt`：`(struct ...)` 被当作声明，不是指令。
- `test/repr-test.rkt`：类型、布局、字面值、slot repr 的回归测试。
