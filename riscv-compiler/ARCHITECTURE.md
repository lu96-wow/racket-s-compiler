> **目标已修正（见 `FASM.md`）**：本文件的 C-like Layer 1/2 自举计划不再是主目标。
> 新主轴是 **汇编 -> 函数式汇编（F-asm）-> Scheme**，不兼容 C。
> 本文件保留作 bootstrap / legacy 参考。

# 三层架构：Racket → S-expression C → Scheme 自举

> 三层，各自只依赖下一层的产物。
> 宏只存在于编译前；后端只有一种 C 模型。

```text
┌ Layer 3  Scheme：自举 + 两语言共享宏 ───────────────────┐
│  M  : expand : S-expression -> S-expression              │
│  C1 : C-like 编译器，Scheme 实现                         │
│  S1 : Scheme 编译器，Scheme 实现                         │
│  C2 : C-like 编译器，C-like 实现，自举定点               │
└──────────────────────────┬───────────────────────────────┘
                           │ 使用 Scheme
┌ Layer 2  C-like 实现 Scheme ────────────────────────────┐
│  runtime / value repr / reader / eval / GC               │
│  S0 : Scheme 解释器，C-like 实现                         │
└──────────────────────────┬───────────────────────────────┘
                           │ 使用 C-like
┌ Layer 1  Racket 宿主：S-expression C 编译器 ────────────┐
│  C0 : source -> expand -> AST -> asm -> program          │
│  后端：CFG / liveness / coloring / activation / layout   │
└──────────────────────────────────────────────────────────┘
```

---

## Layer 1：Racket 上的 S-expression C 编译器

### 1.1 职责

- 在 Racket 上实现 `C0`。
- 输入 C-like 源 S-expression，输出 RISC-V 程序 S-expression。
- 编译器本身是一串显式的 S-expression 变换。
- 不实现 Scheme：Scheme 是 Layer 2 的事。

### 1.2 阶段

```text
source
  -> validate
  -> expand        (M0，与 Layer 3 的 M 同协议)
  -> AST           类型/作用域已解析，宏已消失
  -> select        AST -> vreg asm
  -> cfg
  -> branch-opt
  -> cfg
  -> liveness
  -> interference
  -> coloring
  -> spill         循环：spill -> 重建 CFG/liveness -> 再着色
  -> call-lower
  -> activation    栈帧布局
  -> prologue      插入 prologue/epilogue
  -> layout        label -> address
  -> program
```

### 1.3 源语言形式

```racket
(program
  (global counter int 0)
  (struct point
    (field x int)
    (field y int))
  (func add
    (params (param a int) (param b int))
    (returns int)
    (body
      (let s int (add a b))
      (return s))))
```

类型：

```racket
(int) (char) (void)
(ptr T) (array T n) (struct name) (func (T ...) T)
```

表达式：

```racket
(int 42) (char 65) (string "hi") (var x)
(add a b) (sub a b) (mul a b) (div a b) (mod a b)
(eq a b) (ne a b) (lt a b) (le a b) (gt a b) (ge a b)
(and a b) (or a b) (not a)
(band a b) (bor a b) (bxor a b) (shl a b) (shr a b)
(ref x) (deref p) (index a i) (field s f)
(call f a ...)
(cast T e)
```

语句：

```racket
(let x T e)
(set place e)
(if e then else)
(while e body)
(block stmt ...)
(return e)
(break)
(continue)
(call f a ...)
```

`place`：

```racket
x | (deref p) | (index a i) | (field s f)
```

### 1.4 宏协议

```racket
(defmacro name (params ...) body ...)
```

- 宏是**编译前**的 `S-expression -> S-expression` 函数。
- `expand` 从外到内：头部是已注册宏就展开，替换后重新检查，直到头部不是宏。
- 核心形式永远是核心形式，宏不能覆盖。
- M0（Racket）和 M（Scheme）遵守同一协议，只是 transformer 的运行宿主不同。
- 展开结果 `expanded` 是 AST 的唯一输入。

### 1.5 AST

```racket
(ast
  (global ...)
  (struct ...)
  (func name
    (params ...)
    (returns T)
    (locals (local x T) ...)
    (body (seq stmt ...))))
```

规则：

- 宏已消失。
- 变量已解析为 `local` / `global`。
- 类型已标注。
- 语句只有核心形式。
- 指令选择只消费 AST。

### 1.6 vreg asm

```racket
(asm
  (label main)
  (copy v0 v1)
  (load-slot v2 slot0)
  (store-slot slot0 v2)
  (call f (args v0) (rets v1))
  (return (v1)))
```

- vreg、slot、label 都是符号。
- 不出现物理寄存器、offset、地址。
- `slot` 对后端是不透明句柄。

### 1.7 activation

```racket
(activation
  (base sp)
  (size 48)
  (offsets ((slot0 . -8) (slot1 . -16)))
  (saved ((ra . -24) (s0 . -32)))
  (outgoing ()))
```

- 只有 C 激活记录，没有 heap frame。
- spill 槽、局部变量槽、outgoing 槽都落在 activation。
- 帧大小 = slots + saved + outgoing。

### 1.8 最终 program

```racket
(program
  (global counter int 0)
  (func add
    (activation ...)
    (labels ((main . 0) (L0 . 24)))
    (code
      (addi t0 x0 1)
      (bge t0 t1 16)
      (jalr x0 ra 0))))
```

### 1.9 Layer 1 验收

- 能编译函数、局部变量、算术、`if`/`while`、调用。
- 能编译指针、数组、struct、字符串。
- 输出确定性：集合排序、gensym 计数器、字段顺序固定。
- `M0` 能展开 `defmacro`，且展开结果与 Layer 3 的 `M` 一致。

---

## Layer 2：C-like 实现 Scheme

### 2.1 职责

- 只用 Layer 1 的 C-like 子集实现一个可运行的 Scheme。
- Scheme 的堆、闭包、环境、GC 全部是 C-like 库，不是编译器模式。
- 产物 `S0`：C-like 写的 Scheme 解释器。

### 2.2 runtime

```text
alloc(size) -> ptr
print-int(n)
print-char(c)
print-string(ptr)
exit(code)
```

GC 根协议第一版：

```text
root-push(ptr)
root-pop()
```

显式 shadow stack，不要求编译器生成 stackmap。

### 2.3 值表示

64 位 tagged word，低位 tag：

```text
000 fixnum
001 char
010 cons
011 symbol
100 string
101 vector
110 closure
111 special
```

堆对象统一头部：`(tag, size)`。

### 2.4 Scheme 数据结构

```text
cons / symbol / string / vector / closure
env：数组或链式帧
closure：(code, env)
```

### 2.5 执行

```text
reader   : 文本 -> S-expression
eval     : S-expression + env -> value
trampoline 实现尾调用
```

第一版只做解释器；编译器放到 Layer 3。

### 2.6 Layer 2 验收

- 算术、递归、闭包、尾递归、`let`/`lambda`/`if`。
- 能读入并求值一组最小 Scheme 程序。
- 所有实现代码只使用 Layer 1 的 C-like 子集。

---

## Layer 3：Scheme 自举 + 统一宏

### 3.1 职责

- Scheme 同时是宏语言和编译器实现语言。
- `M` 服务 C-like 和 Scheme 两个编译器。
- `C1` 用 Scheme 实现 C-like 编译器。
- `S1` 用 Scheme 实现 Scheme 编译器。
- `C2` 用 C-like 实现 C-like 编译器，完成自举。

### 3.2 统一宏

```text
expand : S-expression -> S-expression
```

- 只发生在编译前。
- C 编译器和 Scheme 编译器调用同一个 `expand`。
- `defmacro` 的 transformer 是 Scheme 函数。
- 展开结果 `expanded` 是两个编译器共同的输入契约。
- AST 以下不存在宏。

### 3.3 两个编译器

```text
C1 : C-like source -> expanded -> AST -> program
S1 : Scheme source -> expanded -> C-like source | program
```

- `C1` 和 `S1` 共享 `M`、reader、错误报告。
- `C1` 的输出契约与 `C0` 完全一致。
- `S1` 第一版输出 C-like source，复用 Layer 1 的后端。

### 3.4 自举链

```text
C0 : Racket 实现，编译 rt + S0
S0 : C-like 实现，运行 C1 / S1 / M
C1 : Scheme 实现，编译 C2
C2 : C-like 实现，编译自己 -> C3
C2 == C3
```

定点检查：

```text
C1 编译 C2 源 -> C2
C2 编译 C2 源 -> C3
C2 输出 == C3 输出
```

### 3.5 Layer 3 验收

- 同一份 `defmacro` 源码同时被 `C1` 和 `S1` 正确展开。
- `S1` 能编译 `S0`，行为一致。
- `C2` 自举定点成立。
- 输出确定性，定点可字节比较。

---

## 层间契约

| 边界 | 产出方 | 消费方 | 产物 |
| --- | --- | --- | --- |
| L1 → L2 | `C0` | runtime / `S0` | RISC-V program + ABI |
| L2 → L3 | `S0` | `C1` / `S1` / `M` | Scheme runtime + reader + eval |
| L3 → L1 | `C1` / `C2` | runtime | 同构的 program 契约 |

runtime ABI：

```text
args      : a0..a7
returns   : a0
saved     : s0..s11
ra        : 调用点保存
stack     : 16 字节对齐
```

---

## 不变量

1. 宏只在 AST 之前；`expanded` 以下没有宏。
2. 后端只有 C activation model。
3. Scheme 的 heap/closure/GC 只属于 Layer 2 runtime。
4. Layer 2 只用 C-like 子集，不依赖编译器内部。
5. Layer 3 只用 Scheme，不直接碰后端数据结构。
6. 每个阶段 = 一张表 + 一次统一 rewrite。
7. 输出确定性，自举可定点比较。
8. 未知形式/指令直接 `error`，不静默猜测。

---

## 里程碑

| # | 内容 | 退出条件 |
| --- | --- | --- |
| M1 | 冻结 source / expanded / AST 形式 | Layer 2、Layer 3 可直接按此实现 |
| M2 | 后端 activation + spill + callconv | 能编译并运行带调用的函数 |
| M3 | `C0` 最小前端 | 函数、局部变量、算术、`if`/`while`、call |
| M4 | 最小 runtime | alloc / print / exit 可运行 |
| M5 | `S0` 解释器 | 能跑算术、递归、闭包、尾递归 |
| M6 | `M` + `C1` + `S1` | 两编译器共享宏，输出与 `C0` 一致 |
| M7 | `C2` 自举 | `C2 == C3` 定点 |
