# F-asm：函数式汇编（新目标）

> **目标修正：不再走 C 兼容路线。**
> 新主轴：**汇编 -> 函数式汇编（F-asm）-> Scheme**。
> `ARCHITECTURE.md` 里的 C-like Layer 1/2 降级为 bootstrap/legacy 参考。
> 当前 stack policy（栈帧、SysV 式 a0/a7、s0..s11）只是让后端先跑起来的
> **临时 concrete policy**，不是 F-asm 的语义。

---

## 0. 三层，不再有 C 层

```text
┌ Layer 2  Scheme ─────────────────────────────────────────┐
│  reader / expand / core Scheme / compiler / library      │
│  目标：Scheme 编译到 F-asm，最终自举                      │
└──────────────────────────┬───────────────────────────────┘
                           │ 编译
┌ Layer 1  F-asm（函数式汇编）──────────────────────────────┐
│  tagged value / heap frame / closure / continuation      │
│  tail call / GC safepoint / roots                        │
│  目标：Scheme 运行时的“机器无关汇编”                      │
└──────────────────────────┬───────────────────────────────┘
                           │ 指令选择 + 寄存器分配 + lowering
┌ Layer 0  RISC-V asm ──────────────────────────────────────┐
│  vreg asm / CFG / liveness / coloring / layout           │
│  runtime primitives: alloc / GC / cons / print / exit    │
└───────────────────────────────────────────────────────────┘
```

关键变化：

- **没有 C-like 源语言层。**
- **没有 C ABI。**
- F-asm 不是“C 的三地址 IR”，而是 **Scheme 运行时的汇编**。
- stack policy 只是 Layer 0 的一种 bootstrap lowering；
  目标 lowering 是 **heap frame + closure + continuation**。

---

## 1. F-asm 的职责

F-asm 要能直接表达 Scheme 的核心运行时：

- 一个机器字一个值（tagged value）
- 堆对象：pair / symbol / string / vector / procedure
- 词法环境：heap frame + link
- 闭包：code + env
- 续延：code + env（procedure 的一种）
- 应用、尾调用、返回
- GC safepoint / roots
- 算术、比较、`eq?` 等 primitive
- `alloc`

F-asm 不负责：

- 宏展开
- 源码作用域解析
- 类型推导
- 机器码编码
- 具体 GC 算法
- 寄存器分配（那是 Layer 0 的事）

---

## 2. 值表示：一个机器字

64 位 tagged value，低 3 位：

```text
000  fixnum（signed 61-bit）
001  char
010  cons pointer
011  symbol pointer
100  string pointer
101  vector pointer
110  procedure pointer（closure / continuation）
111  special
```

special = `(code << 3) | 7`：

| 值 | 编码 |
|---|---:|
| `#f` | 7 |
| `#t` | 15 |
| `'nil` | 23 |
| `eof` | 31 |

约定：

- **所有 Scheme 可见值都是 tagged。**
- 寄存器、frame slot、参数、返回值里只放 tagged value。
- 原始 `b8/b16/b32/b64` / `pb*` 只用于 runtime 内部
  （例如 bytevector 的 payload、GC 的位图、长度）。
- 因为值自带 tag，GC 扫描 frame/寄存器时**不需要逐槽类型图**：
  看到 pointer tag 就跟随。
  这是选择 tagged value 的最大收益。

---

## 3. 堆对象

统一头部：`(type, size)`（具体编码由 Layer 0 决定）。

```text
pair       : header, car, cdr
symbol     : header, name
string     : header, length, bytes...
vector     : header, length, elems...
procedure  : header, code, env
box        : header, value
frame      : header, link, slot0..slotN
```

- `procedure` 同时表示 closure 和 continuation。
  `procedure?` 对两者都为真。
- `set!` 的变量用 `box`；frame 本身不可变。
- frame 不可变是 multi-shot continuation 的前提：
  捕获续延 = 捕获 `(code, env)`，不需要复制整个栈。

---

## 4. frame：词法环境

```text
frame:
  header
  link        ; 指向外层 frame
  slot0
  slot1
  ...
```

- `fp` 指向当前 frame。
- `(env depth index)`：
  - `depth` 是 de Bruijn 词法距离：0 = 当前 frame，1 = 外层，2 = 再外层。
  - `index` 是 frame 内槽号。
- frame 只读；需要可变就用 `box`。
- 参数、局部变量、溢出值、闭包捕获的值**共用同一张 frame 表**。

### 4.1 调用时 frame 怎么来

推荐第一版：**callee 自己分配 frame**。

```text
caller:
  把参数放进一个 value vector（argv）
  创建 continuation（非尾调用）
  跳 callee code

callee entry:
  alloc frame（link = closure.env）
  把参数存进 frame slot
  fp = new frame
  执行 body
```

- 非尾调用：caller 创建 continuation `{code Lafter, env caller-fp}`。
- 尾调用：不创建 continuation，callee 分配新 frame，旧 frame 变成垃圾。
- 每次调用分配 frame 是函数式模型的正常代价；
  以后可以用 escape analysis 把非逃逸 frame 放回机器栈。
- 因为 frame 在堆上，尾调用不会增长机器栈；
  GC 会回收旧 frame。

---

## 5. 闭包、应用、续延

### 5.1 闭包

```text
closure = { code, env, arity }
```

- `env` 是闭包定义点的 frame。
- 应用闭包：`fp = closure.env`，跳 `closure.code`。
- callee 的 frame `link = closure.env`，
  所以 `(env 1 i)` 访问捕获变量。

### 5.2 调用约定：只传 value vector

**纯模型里没有 `a0..a7`。** 参数和返回值都是 **value vector**：

```text
参数        : 一个 value vector（argv）
返回值      : 一个 value vector（vals）
incoming    : argv 抽象寄存器
continuation: k 抽象寄存器
当前 frame  : fp 抽象寄存器
```

- `(pack dst r...)` 构造一个 value vector。
- callee 用 `(arg-ref dst i)` / `(arg-count dst)` 读取 incoming vector。
- `call` / `tailcall` 把 argv 设为 callee 的 incoming vector。
- `return` 把 vals 设为 continuation 的 incoming vector。
- `call/cc` 传给 f 的 incoming vector 是 `#(k)`。

真实寄存器（a0..a7、s0..s11、栈）是 **Layer 0 的优化**，
不属于 F-asm 语义。F-asm 只假设“有一个 value vector 被传递”。

- **没有 caller-saved / callee-saved 的语义。**
  跨调用的值要么在 frame 里，要么被 continuation 捕获。
- **没有固定 `ra` 的语义。**
- **尾调用不分配 continuation。**
  `(tailcall f argv)` = argv 就位，`k` 不变，跳 f。

### 5.3 三种控制操作

```racket
(pack argv v0 v1)                ; 构造 value vector
(call f argv (cont k))           ; 非尾调用：调用 f，参数向量 argv
(tailcall f argv)                ; 尾调用：k 不变，跳 f
(pack vals v)                    ; 构造返回值向量
(return vals)                    ; 调用当前 k
```

语义：

```text
(call f argv k)
  = jump f with incoming = argv, k = 给定的 k

(tailcall f argv)
  = jump f with incoming = argv, k unchanged

(return vals)
  = jump k.code with incoming = vals, fp = k.env, k = k.next
```

语法糖：

```racket
(call f (args r...) (cont k))    ; 等价于 (pack argv r...) + (call f argv ...)
(return (r...))                  ; 等价于 (pack vals r...) + (return vals)
```

编译器内部使用纯形式；`args`/`return` 列表形式只是手写时的简写。

- **continuation 不是单个 `{code, env}`，而是链：**

```text
continuation = { code, env, next }
```

- `call`：安装一个新的 continuation 头，`next` 指向旧的 `k`。
- `return`：跳到 `k.code`，`fp = k.env`，然后 `k = k.next`。
- `tailcall`：`k` 原样传下去。
- `call/cc`：把当前 `k` 链头具体化成 procedure 值；
  调用它时恢复 `fp = k.env`，`k = k.next`，把参数放进 `a0`，跳 `k.code`。
- one-shot continuation 可以把 `ra` 当快速缓存；
  但语义上是链，不是单个返回地址。
- multi-shot：continuation 对象不可变，frame 链共享；
  `set!` 的可变状态要么共享 frame slot，要么用 box（见 §14 的原型取舍）。

---

## 6. F-asm 形式

F-asm 是 S-expression，保持“标签开头、可打印、可测试”。

### 6.1 函数

```racket
(func name
  (params (p0 value) (p1 value))
  (frame (size n))
  (body
    (label name)
    ...))
```

### 6.2 环境 / 值 / 分配

```racket
(alloc-frame n)                 ; 新 frame，link = 当前 fp；fp = 新 frame
(env-ref dst (env depth index))
(env-set (env depth index) src)

(const dst #t)                  ; 15
(const dst #f)                  ; 7
(const dst 'nil)                ; 23
(const dst 42)                  ; fixnum

(closure dst code arity)        ; 捕获当前 fp
(cont dst code)                 ; { code, env = fp, next = 当前 k }

(pack dst r...)                 ; 构造 value vector
(arg-ref dst index)             ; 读取 incoming value vector
(arg-count dst)                 ; incoming vector 长度（fixnum）
```

### 6.3 控制

```racket
(call f argv (cont k))          ; argv 是持有 value vector 的 vreg
(tailcall f argv)
(return vals)                   ; vals 是持有 value vector 的 vreg

;; 手写简写（语义仍是 value vector）：
(call f (args r...) (cont k))
(tailcall f (args r...))
(return (r...))
```

### 6.4 primitive

```racket
(prim add dst a b)
(prim sub dst a b)
(prim eq dst a b)
(prim cons dst car cdr)
(prim car dst pair)
(prim cdr dst pair)
(prim procedure? dst f)
(prim display dst value)
```

具体 primitive 表由 runtime 决定，F-asm 只规定调用形状。

### 6.5 分支 / 移动

```racket
(move dst src)
(jump L)
(branch-if r L)                 ; r 不是 #f 就跳
(branch-if-not r L)             ; r 是 #f 就跳
```

### 6.6 safepoint / roots

```racket
(safepoint S0)
(roots S0
  (reg fp k a0)
  (frame (env 0 0) (env 0 3)))
```

- `alloc` 和 `call` 可能触发 GC。
- 在 safepoint，所有 live Scheme 值必须在 roots 里：
  寄存器里的 tagged value，或沿 `fp` 可达的 frame slot。
- 因为值自带 tag，roots 不需要逐槽类型；
  但需要知道“哪些寄存器是 live”。第一版可以：
  - 在 safepoint 前把 live 值全部写回 frame；
  - 或由 codegen 生成寄存器 mask。
- 推荐第一版用“写回 frame”，简单且和 spill 模型一致。

---

## 7. GC

第一版建议：**copying / nursery + 后续 mark-sweep**，或者直接 mark-sweep。

不变量：

1. 所有 Scheme 可见值都是 tagged。
2. frame 只读；可变状态在 box。
3. roots = `fp` 链 + `k` + safepoint 的 live 寄存器。
4. GC 可以移动对象，但必须更新 roots 和 frame 里的指针。
5. runtime 内部的 raw word 必须放在有类型描述的结构里，不能混进 frame slot。

如果使用 tagged value + 所有 Scheme 值都在 frame/寄存器，
GC 可以做到**精确且不需要 stack map 的逐槽类型**；
只需要 live register mask 或 safepoint 前的写回。

---

## 8. Scheme 层

F-asm 之上是 Scheme：

```text
reader        : 文本 -> S-expression
expand        : define-syntax / syntax-rules 或 Lisp 宏
core          : 变量 / lambda / application / if / quote / letrec / set!
frontend      : core -> closure conversion -> F-asm
library       : list / arithmetic / equal? / assoc / map ...
eval          : 可选，用 Scheme 写在 F-asm 之上
```

第一阶段只需要：

- fixnum / boolean / symbol / pair / procedure / nil
- `lambda` / 应用 / `if` / `quote` / `define` / `letrec`
- 闭包、尾调用
- `cons/car/cdr`、`eq?`、算术
- `apply`、`procedure?`

`set!` 可以用 box；`call/cc` 可以后加。

---

## 9. 编译流水线

```text
Scheme source
  -> reader
  -> expand
  -> core Scheme
  -> closure conversion / frame layout
  -> F-asm
       (value / env-ref / env-set / closure / cont
        call / tailcall / return / prim / safepoint)
  -> instruction selection
  -> vreg asm
  -> CFG / liveness / interference / coloring / spill
  -> F-asm lowering
       (heap frame allocation, closure creation,
        continuation, call/return, roots)
  -> RISC-V asm
  -> layout / encoding
```

Layer 0 现有的 `cfg / liveness / interference / coloring / layout`
可以继续用；它们不关心值是不是 Scheme 值。

---

## 10. 当前代码的去留

### 保留

| 文件 | 原因 |
|---|---|
| `asm.rkt` / `cfg.rkt` / `liveness.rkt` / `interference.rkt` | 机器无关的底层分析 |
| `regalloc-graph.rkt` / `layout.rkt` / `program.rkt` | Layer 0 |
| `frame.rkt` / `repr.rkt` | 形式和表示类型 |
| `regalloc-cache.rkt` | “spill = 缓存驱逐”，和 F-asm 的 frame 模型一致 |
| `test/core-test.rkt` / `test/cache-test.rkt` | 回归 |

### 降级为 bootstrap

| 文件 | 说明 |
|---|---|
| `lower-frame.rkt` | 当前是 stack frame + prologue；目标换成 heap frame 分配 |
| `call-lower.rkt` | 当前是 `ra`/C 风格；目标换成 continuation + heap frame |
| `examples/frame-asm.sexpr` | stack policy 示例，保留作对照 |

### legacy / 可选

| 文件 | 说明 |
|---|---|
| `ARCHITECTURE.md` 的 C-like Layer 1/2 | 不再是主目标 |
| `DESIGN.md` 里 C activation / SysV 部分 | 只作为 Layer 0 bootstrap 参考 |
| `FORMS.md` 里 C 风格的形式 | 保留作历史，不是 F-asm 规范 |

### 新增（待做）

| 内容 | 作用 |
|---|---|
| `FASM.md` | 本文，权威 F-asm 规范 |
| `fasm-interp.rkt` | Racket 里的 F-asm 参考解释器 |
| `fasm-lower.rkt` | heap frame / closure / continuation lowering |
| `runtime/` | alloc / GC / primitives |
| `scheme/` | reader / expand / compiler |

---

## 11. 里程碑

### M0：冻结 F-asm

- 值表示、frame、closure、continuation、call/tailcall/return
- safepoint/roots 的形状
- 哪些是 F-asm，哪些是 Layer 0

**退出条件**：`FASM.md` 中的形式可以手写，且能说清语义。

### M1：F-asm 参考解释器（已完成原型）

- Racket 实现，不依赖 RISC-V
- 支持 closure、tail call、continuation 链、`call/cc`、box、safepoint
- 用测试验证：递归、尾递归、闭包捕获、one-shot / multi-shot `call/cc`

**退出条件**：F-asm 程序可以直接在 Racket 里跑，作为语义 oracle。

状态：已实现 `fasm-interp.rkt` + `scheme-core.rkt`；
`test/fasm-test.rkt` 覆盖 1419 项测试（含旧后端测试）。

### M2：Scheme core -> F-asm

- Racket 写的 Scheme 编译器
- 只支持核心形式 + 少量 primitive
- 在 M1 的解释器上跑

**退出条件**：能跑递归、闭包、尾递归、列表程序。

### M3：RISC-V 后端 + runtime

- F-asm -> vreg asm -> RISC-V
- heap frame allocation、closure、continuation
- alloc / GC / cons / print
- safepoint roots

**退出条件**：M2 的程序在 RISC-V 上跑通；尾调用不增长栈。

### M4：宏 + 库

- `define-syntax` / `syntax-rules` 或 Lisp 宏
- list / arithmetic / equal? / map / assoc

### M5：自举

- 用 Scheme 写 Scheme 编译器
- 用 M2 编译它
- 用 M3 运行它
- 再编译自己，检查定点

### 可选

- multi-shot continuation
- `dynamic-wind` / 异常
- 线程 / engine
- escape analysis + stack frame 优化

---

## 12. 需要尽早定的决策

| # | 问题 | 建议默认 |
|---|---|---|
| 1 | CPS 还是 direct + explicit continuation | direct + explicit continuation；one-shot 用 `ra` 快速路径 |
| 2 | frame 由 caller 还是 callee 分配 | callee 分配；caller 只传参数 |
| 3 | 参数传递 | 一个 value vector；真实寄存器是 Layer 0 优化 |
| 4 | 多值返回 | 一个 value vector；多值就是多个元素 |
| 5 | frame 可变吗 | 不可变；`set!` 用 box |
| 6 | continuation 是否 multi-shot | 先 one-shot；frame 持久化，后续支持 multi-shot |
| 7 | GC 算法 | 先 copying/nursery，后 mark-sweep |
| 8 | 原始宽度类型 | 只给 runtime 内部；Scheme 默认 `value` |
| 9 | safepoint roots | 第一版 safepoint 前把 live 值写回 frame |
| 10 | 尾调用旧 frame | 交给 GC；不做显式回收 |
| 11 | value vector 的物理表示 | 语义上是抽象 tuple；Layer 0 可用寄存器组、栈传参区或 heap vector |

---

## 13. 一句话

> **F-asm 不是“C 的汇编”，而是“Scheme 运行时的汇编”：**
> 一个机器字一个 tagged value，
> 环境是 heap frame，
> 闭包是 code + env，
> 续延是 code + env，
> 调用是捕获续延，尾调用是换环境，
> GC 靠 tag 精确扫描。

C 兼容不再是目标；当前 stack policy 只是 bootstrap。

---

## 14. 原型状态（已实现）

### 14.1 文件

| 文件 | 作用 |
|---|---|
| `fasm.rkt` | tagged value 编码、F-asm 程序/label 形式 |
| `fasm-interp.rkt` | Racket 参考解释器：heap frame、closure、continuation 链、tail call、`call/cc` |
| `scheme-core.rkt` | mini Scheme core -> F-asm 编译器 |
| `test/fasm-test.rkt` | 值、解释器、编译器、递归、尾递归、`call/cc`、multi-shot、`set!`、display |
| `examples/fasm-demo.rkt` | 可运行 demo：算术、闭包、factorial、尾递归、call/cc、quote、set! |
| `visualizer/index.html` | 交互式动画：逐步看 pc/fp/k/argv/frame 的变化 |
| `visualizer/README.md` | 动画使用说明 |

### 14.2 已经验证

- 字面量：fixnum / `#t` / `#f` / `'nil` / char / symbol / quoted list
- heap frame + lexical link：`(env depth index)`
- 闭包捕获 + 调用
- 非尾调用：continuation 链在 heap 上，host 栈恒定
- 尾调用：不分配 continuation；100000 次尾递归可跑
- `call/cc`：one-shot 和 multi-shot（同一个 continuation 调用两次）
- `let` / `letrec` / 互递归
- `set!`：直接写 frame slot（共享 frame，符合 Scheme 的共享 store 语义）
- `box` / `unbox` / `set-box!`
- `display` / `newline`
- 跨调用的临时值：调用前写回 frame，返回后恢复；
  这是原型里发现的关键点：**vreg 不能跨 call 存活**
- **参数/返回值只走 value vector**：`pack` / `arg-ref` / `return vals`；
  编译器输出里没有 `a0..a7`
- 真实寄存器传递是后续 Layer 0 优化，不在 F-asm 语义里

### 14.3 原型里的取舍

- **没有 GC**：heap 只增不减。尾递归 100000 次可以跑，但内存单调增长。
- **`set!` 直接写 frame slot**：没有用 box。
  因为 continuation 捕获的是 frame 指针，frame 共享，
  这正好符合 Scheme 的 shared store 语义；但 frame 不是“不可变”的。
  以后如果为 multi-shot 复制 frame，就必须改成 box。
- **`call/cc` 的 continuation 是链**，不是单个 `{code, env}`。
- **没有 `define` / 顶层环境**：用 `letrec` 表达递归。
- **没有多值**：`return` 只取第一个值。
- **没有可变参数**：lambda 参数必须固定。
- **没有宏 / cond / let* / and / or**：下一步再加。
- **primitive 有限**：`+ - * / mod = < <= > >= cons car cdr
  null? pair? procedure? eq? box unbox set-box! display newline call/cc`。
- **没有 string/vector 操作**、`apply`、异常、`dynamic-wind`。

### 14.4 下一步

1. **GC**：先 mark-sweep 或 copying，roots = frame 链 + `k` + live 寄存器。
2. **`define` / 顶层 frame**，让程序不必全包在 `letrec` 里。
3. **宏 / `cond` / `let*` / `and` / `or`**。
4. **多值 / 可变参数**。
5. **把原型 lowering 接到 Layer 0**：F-asm -> vreg asm -> RISC-V。
6. **用真实的 register allocator** 替换“调用前全量 spill”的原型策略。
   原型里 spill 所有已定义 vreg，正确但很重。
