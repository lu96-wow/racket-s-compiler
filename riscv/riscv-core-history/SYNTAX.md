# riscv-core 表面语法

本文定义核心 s-exp 的形状。所有形状都是 proper list；不使用 dotted pair，
不依赖 symbol 字符串前缀。

## 1. 顶层

没有 `unit` 包装。顶层是 `func` / `data` / `raw`，或者用 `module` 分组：

```scheme
(module (lib)
  (provide (f))
  (func (f)
    ...))

(func (main)
  ...)

(data (d table)
  ...)

(raw (start)
  ...)
```

- 多文件、`provide` / `require` 见 [`MODULES.md`](MODULES.md)。
- `raw` 和 `asm` 见 [`ASM.md`](ASM.md)。
- `func` / `data` / `raw` 的名字是**全局链**：`(main)`、`(lib f)`、`(d table)`。
- block 名是**函数局部 symbol**：`b0`、`loop`、`exit`。
- 虚拟寄存器是 `($ name)`。
- 全局引用是 `(global chain)`。
- 物理寄存器是 `(native xN)`，只出现在 `alloc` 约束、`asm` 的
  inputs/outputs/clobber，或 machine IR。
- 立即数直接写整数。

形状判断全部用 list 操作：

```racket
(match x
  [(list '$ (? symbol? n)) ...]          ; ($ name)
  [(list 'native (? symbol? r)) ...]     ; (native xN)
  [(list 'global (? path? p)) ...]       ; (global chain)
  [(? exact-integer? n) ...])
```

`data` 的 body 形状见 [`DATA.md`](DATA.md)：第一版支持 `(align n)` /
`(bytes ...)` / `(fill n b)` / `(value w v)`。跨模块变量是 `data` +
`addr` / `load` / `store`。

## 2. 函数

```scheme
(func (main)
  (vregs
    (($ a) (b8))
    (($ b) (b8))
    (($ t) (b64) (align 8)))

  (alloc
    (reserve (native x5))
    (pin ($ t) (native x11))
    (clobber (native x5) (native x6)))

  (entry b0)

  (block b0
    ...)
  ...)
```

### 2.1 `vregs`

每个条目至少是二元 list；可以带 options：

```scheme
(vregs
  (($ name) type option ...)
  ...)
```

- 第二项是类型。
- `option` 可选：`(align n)`、`(address-taken)`。
- `(address-taken)` 表示这个 vreg 的地址会被取；分配时必须给它 `(slot n)`。
- 变量先当作虚拟寄存器；这里不出现 `(slot ...)`。

类型：

```scheme
(b8) (b16) (b32) (b64)
(s8) (s16) (s32)
(ptr)
```

- `(bN)` / `(sN)` 描述**存储宽度**：load/store/spill 时用。
- 算术值统一按 XLEN；窄算术不在核心 IR 里隐式发生。
- `(ptr)` 表示 XLEN 指针。
- 不引入 `uint` / `int` 类型；符号性由 load/store 类型和操作名表达。

### 2.2 `alloc`

`alloc` 是分配约束，不是代码：

```scheme
(alloc
  (reserve (native x5))
  (pin ($ t) (native x11))
  (clobber (native x5) (native x6)))
```

- `reserve`：这个物理寄存器不参与普通分配（例如 scratch）。
- `pin`：这个 vreg 必须落在指定物理寄存器。
- `clobber`：本函数内调用会破坏的物理寄存器集合（保守并集）；不是 C ABI，只是效果集合。

`alloc` 里的 `(native ...)` 不是代码操作数，允许存在。

### 2.3 `entry`

```scheme
(entry b0)
```

每个函数恰好一个入口 block。

### 2.4 `frame` / `scratch`（machine 侧）

分配/物化之后才出现：

```scheme
(frame
  (size 48)
  (header 16)
  (outgoing 0)
  (align 16)
  (slots
    (slot 0 (offset 17) (size 1) (align 1))
    (slot 1 (offset 40) (size 8) (align 16))))

(scratch (native x5))
```

- `frame` 由 `frame-layout` 产出；`slot offset` 是 FP 到 slot 低地址的距离，
  地址 = `FP - offset`。
- `header` 默认 16：saved RA + saved old FP。
- 不写 `sp` / `fp` / C ABI；物理寄存器用 `(native xN)`。
- `scratch` 是 materialize 可以使用的物理寄存器，由分配层给出；可以写多个。

内存模型、runtime contract、stack map 见 [`MEMORY.md`](MEMORY.md)。

## 3. block

```scheme
(block b0
  op ...
  (term ...))
```

- 一个 block 恰好一个 terminator，必须是最后一个 form。
- 没有隐式 fallthrough；没有 term 的 block 非法。
- block 内 op 顺序执行；op 不能是控制转移。

## 4. terminator

```scheme
(term (jump b1))
(term (branch cond b1 b2))
(term (return operand ...))
(term (trap))
```

- `(jump b1)`：一条边。
- `(branch cond b1 b2)`：两条边，`b1` 是条件为真，`b2` 为假。
- `(return ...)`：抽象返回，没有局部后继。
- `(trap)`：终止，没有局部后继。

条件：

```scheme
(eq a b)
(ne a b)
(lt a b)       ; signed
(le a b)
(ltu a b)      ; unsigned
(leu a b)
```

操作数 `a` / `b` 是整数或虚拟寄存器。条件是 term 的一部分，不单独物化成布尔值。
全局地址要比较时，先用 `addr` 装进 vreg。

`jump` / `branch` 是**边**，不是 `j` / `b` 指令。布局层才决定
fallthrough、`j`、`b`、远跳。

## 5. 操作

操作数：

```scheme
operand := integer
         | ($ name)
         | (global chain)
```

核心操作统一目标在前：

```scheme
(const ($ t) 42)
(copy ($ t) ($ a))
(add ($ t) ($ a) ($ b))
(add ($ t) ($ a) 1)
(load ($ t) ($ p) 0 (b8))
(store ($ p) 0 ($ t) (b8))
(addr ($ p) (global (d table)))
(call ($ r) (global (lib f)) ($ a) ($ b))
```

完整操作表见 [`OPS.md`](OPS.md)。

`asm` 是特殊 op，不遵循“目标在前”的普通 op 形状；它的边界由
`inputs` / `outputs` / `clobber` 给出，详见 [`ASM.md`](ASM.md)。

## 6. allocation

分配前没有 `allocation`，只有 `vregs`。

分配后：

```scheme
(allocation
  (($ a) (native x10))
  (($ b) (slot 0))
  (($ t) (native x11)))
```

- 条目是**二元 proper list**，不写 dotted pair。
- car 是虚拟寄存器，cadr 是位置。
- `vregs` 的 `(($ a) (b8))` 和 `allocation` 的 `(($ a) (native x10))` 形状相同，
  都是二元 list；第二项分别是 type / location。
- 位置：`(native xN)` 或 `(slot n)`。
- 未分配就是没有条目；分配后仍缺条目是错误。

查找是普通 list 操作：

```racket
(cadr (assoc '($ a) (cdr allocation)))
```

## 7. machine IR

machine IR 的值/地址只允许：

```scheme
(native xN)        ; 值：物理寄存器
(frame-slot n)   ; 地址：frame 槽
42
(global chain)
```

不允许 `($ name)`。block / term 形状不变。

`(slot n)` 只是 allocation 的 location；machine IR 里用 `(frame-slot n)`
表示它的地址，它不是独立的 machine 值操作数。

这是 materialize 之后的 machine IR。`load` / `store` / 条件还会在
`lower-ops` / `layout` 里选成具体 native 形式；block / term 形状不变。

```scheme
(func (main)
  (frame
    (size 32)
    (header 16)
    (outgoing 0)
    (align 16)
    (slots
      (slot 0 (offset 24) (size 8) (align 8))))
  (scratch (native x5))
  (entry b0)

  (block b0
    (load (native x5) (frame-slot 0) 0 (b64))
    (add (native x11) (native x10) (native x5))
    (term (branch (eq (native x11) 0) b1 b2)))
  ...)
```

`(slot n)` 是 allocation 里的位置；`(frame-slot n)` 是 machine IR 里的
内存地址形式。`frame-layout` 把 slot 变成 `FP - offset`，不是 C ABI。

## 8. 禁止项

核心 IR 中禁止：

```scheme
(unit ...)        ; 不需要
(uint ...)        ; 不需要
a0 / ra / sp      ; C ABI 名字
(j ...) / (beq ...) / (label ...)   ; 控制流编码
($var)            ; 字符串式虚拟寄存器
(($ a) . (native x10))             ; dotted pair
```

控制流只用 `(term ...)` 的 `jump` / `branch` / `return` / `trap`。

例外是明确的：

- `module` / `provide` / `require` 只在前端存在，后端输入里不应出现。
- `raw` 是纯汇编，本来就是 machine 层，可以出现 `label` / `j` / `b`。
- `asm` 是内嵌汇编，`code` 内部是 machine 层；边界由 inputs/outputs/clobber 显式化。

详见 [`MODULES.md`](MODULES.md) 和 [`ASM.md`](ASM.md)。
