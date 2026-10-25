> **目标已修正（见 `FASM.md`）**：不再走 C 兼容路线。
> 新主轴是 **汇编 -> 函数式汇编（F-asm）-> Scheme**。
> 本文里的 stack policy（栈帧、a0/a7、s0..s11）只是 bootstrap，
> 不是 F-asm 的目标语义。F-asm 用 heap frame + closure + continuation。

# riscv-compiler 当前设计状态

> 这份文档只描述“现在真实可运行/可测试的状态”，
> 以及“哪些只是设计目标/实验”。用来防止把未来计划当成已实现。

---

## 0. 一句话定位

当前仓库不是完整的 Scheme/C 编译器，也不是 `ARCHITECTURE.md` 里的三层自举系统。

新目标：

> **汇编 -> 函数式汇编（F-asm）-> Scheme，不兼容 C。**
> F-asm 是 Scheme 运行时的汇编：tagged value、heap frame、closure、continuation、GC。

当前实现是：

> **Layer 0 后端骨架 + 一个 stack policy bootstrap + 一层表示类型。**
> 它能让 frame/env/cont/call 先跑起来，但不是 F-asm 的最终 lowering。

具体说：

- 有：CFG、liveness、interference、图着色、layout、frame/env/cont/call 形式、
  表示类型、字面量、stack policy lowering。
- **已有 F-asm 原型**：Racket 参考解释器 + mini Scheme core 编译器，
  支持 heap frame、closure、continuation 链、尾调用、`call/cc`。
- 没有：F-asm -> RISC-V codegen、GC、runtime、reader、宏、自举。
- 目标层级：`FASM.md` 的 F-asm + Layer 0；`ARCHITECTURE.md` 的 C-like 层是 legacy。

### 0.1 F-asm 原型（已跑通）

```text
Scheme core
  -> scheme-core.rkt
  -> F-asm
  -> fasm-interp.rkt（Racket 参考解释器）
```

已验证：

- fixnum / `#t` / `#f` / `'nil` / symbol / quoted list
- heap frame + lexical link `(env depth index)`
- closure `{code, env, arity}`
- continuation 链 `{code, env, next}`
- 非尾调用 / 尾调用 / `call/cc`（one-shot + multi-shot）
- `let` / `letrec` / 互递归
- `set!` / `box`
- `display` / `newline`
- 跨调用临时值写回 frame（vreg 不能跨 call 存活）
- **参数/返回值只走 value vector**：`pack` / `arg-ref` / `return vals`；
  编译器输出里没有 `a0..a7`；真实寄存器是 Layer 0 优化

没有：GC、`define`、宏、多值、可变参数、F-asm -> RISC-V。

---

## 1. 三层架构与当前位置

`ARCHITECTURE.md` 描述的是三层自举计划：

```text
Layer 3  Scheme 自举 + 两语言共享宏
Layer 2  C-like 实现 Scheme runtime
Layer 1  Racket 宿主：S-expression C 编译器
```

当前实际状态：

| 层 | 状态 |
|---|---|
| Layer 1 | **部分实现**：底层 vreg asm -> CFG -> liveness -> coloring -> layout；以及 frame/env/cont lowering |
| Layer 2 | **未实现**：没有 C-like 写的 Scheme runtime/GC/reader/eval |
| Layer 3 | **未实现**：没有 Scheme 写的编译器，没有自举定点 |

所以现在可以讨论“后端怎么表示值和上下文”，
但还不能说“已经有一个能跑的 Scheme”。

---

## 2. 两条输入路径，一个后端

`compile-asm.rkt` 是唯一入口，自动分派两条路径。

### 2.1 纯 vreg asm 路径

输入：

```racket
(asm
  (label main)
  (addi v0 x0 0)
  (bge v0 v1 L0)
  ...)
```

流水线：

```text
asm(vreg)
  -> cfg
  -> branch-opt
  -> cfg
  -> liveness
  -> interference
  -> graph coloring
  -> layout
  -> program
```

特点：

- 只有 vreg、物理寄存器、label。
- 没有 frame、没有调用约定、没有 spill。
- 分不到颜色直接 `error`。
- 这是 `DESIGN.md` / `SKELETON.md` 描述的原路径。

### 2.2 frame / env / cont / call 路径

输入：

```racket
(asm
  (struct point (field x b8) (field y b64))
  (frame
    (base fp)
    (link fp)
    (slots
      (slot0 (kind arg)   (repr b64))
      (slot1 (kind local) (repr value))))
  (label main)
  (const v0 #f)
  (env-set (heap 0 1) v0)
  (env-ref v1 (heap 0 1))
  (cont K0 (code Lafter) (env fp))
  (call f (args v1) (cont K0))
  (label Lafter)
  (return (a0))
  ...)
```

流水线：

```text
asm(vreg + frame/cont/struct/const)
  -> lower-literals          ; const -> addi
  -> lower-frame-forms       ; 抽走 frame/cont/struct；env -> ld/sd；插 prologue
  -> cfg
  -> branch-opt
  -> cfg
  -> liveness                ; call/tailcall/return 仍是伪指令
  -> interference
  -> graph coloring
  -> call-lower              ; 参数并行移动；jal/jalr；epilogue
  -> cfg
  -> branch-opt              ; 清理多余的跳转
  -> layout
  -> program
```

关键顺序：

1. **`const` 在 CFG 之前物化**，不进入 liveness。
2. **`frame`/`cont`/`struct` 是声明，不是指令**，在 CFG 之前抽走。
3. **`call`/`tailcall`/`return` 必须活到 coloring 之后**，
   这样 liveness 才能看见 caller-saved 的隐式 def。
4. `call-lower` 之后再做一次 CFG/branch-opt，清掉冗余跳转。

---

## 3. 数据契约

### 3.1 原有后端

```racket
asm        (asm (label main) (addi v0 x0 0) ...)
cfg        (cfg (blocks ...) (label-map ...) (succ ...))
liveness   (liveness (B0 (use ...) (def ...) (in ...) (out ...)) ...)
interference (interference (v0 ra v1) ...)
coloring   (coloring ((v0 . t1) ...))
layout     (values labels resolved-code)
program    (program (func main (labels ...) (code ...)))
```

详见 `DESIGN.md` / `FORMS.md`。

### 3.2 新增形式

```racket
;; frame
(frame
  (base fp)
  (link fp)
  (slots
    (slot0 (kind arg)   (repr b64))
    (slot1 (kind local) (repr (ptr (struct point))))
    (slot2 (kind spill) (repr value))))

;; 环境访问：depth 0 = 当前 frame
(env-ref dst (heap 0 i))
(env-set (heap 0 i) src)

;; 续延声明与引用
(cont K0 (code Lafter) (env fp))
(cont K0)

;; 调用 / 尾调用 / 返回
(call f (args a0 a1) (cont K0))
(tailcall f (args a0 a1))
(return (a0))

;; 字面值
(const dst #t)      ; 15
(const dst #f)      ; 7
(const dst 'nil)    ; 23
(const dst 42)      ; 原始 b64

;; 结构体
(struct point
  (field x b8)
  (field y b64))
```

存储类别 `kind`：

```text
arg | local | spill | captured | saved | outgoing
```

注意：`kind` 是**存储类别**，不是类型；类型在 `(repr T)`。

---

## 4. 函数式模型 vs 当前具体策略

这是最容易混淆的地方。

### 4.1 逻辑模型（设计原则）

```text
vreg   = 不可变值
frame  = 环境（spill/local/arg/captured 共用一张表）
preg   = 缓存（不是所有者）
cont   = {code, env} 的值
```

由此推出：

- spill = 缓存驱逐，不是“着色失败后的补救”
- 调用 = 捕获续延
- 返回 = 调用续延
- 尾调用 = 换 env，不增长栈
- 保存集合 = liveness 算出的 live set，不是固定 ABI

### 4.2 当前实现（stack policy + one-shot 续延）

| 逻辑概念 | 当前具体化 |
|---|---|
| frame | **栈帧**，`fp` 指向 frame 基址 |
| `(heap 0 i)` | `fp + 16 + 8*i`（x86 风格的 `ld/sd` 形式是 `(ld rd off fp)`） |
| `(heap d i), d>0` | **未实现**，直接报错 |
| cont | **one-shot**：`ra` = code，`fp` = env |
| call | 参数并行移动 -> `jal ra f` -> `jal x0 Lafter` |
| return | 返回值移入 `a0..` -> epilogue -> `jalr x0 ra 0` |
| tailcall | 参数移入 `a0..` -> epilogue -> `jal x0 f` |
| caller-saved | `t0..t6, a0..a7, ra`，由 call 的隐式 def 建模 |
| callee-saved | 当前**固定保存全部** `s0..s11` |
| 寄存器分配 | 主路径仍是图着色；**不 spill** |
| spill 实验 | `regalloc-cache.rkt`，缓存驱逐模型，**未接入主路径** |

### 4.3 明确未实现

- heap frame / heap 续延
- multi-shot `call/cc`
- `dynamic-wind` / 异常 / 线程
- 词法 link（`(heap 1 i)`）
- 多函数各自的 frame/prologue
- GC / roots / pointer map
- 把 `regalloc-cache` 的 spill 接进主路径

---

## 5. frame 布局与调用约定（当前具体值）

```text
frame base = fp
offset 0        old fp（用于 epilogue）
offset 8        ra
offset 16+8*i   slot i
saved area      s0..s11
```

frame size：

```text
align16(16 + 8*slot-count + 96)
```

prologue：

```racket
(addi sp sp -size)
(sd fp 0 sp)
(sd ra 8 sp)
(sd s0 off sp) ... (sd s11 off sp)
(addi fp sp 0)
```

epilogue：

```racket
(ld ra 8 fp)
(ld s0 off fp) ... (ld s11 off fp)
(ld fp 0 fp)
(addi sp sp size)
```

调用约定：

```text
args      : a0..a7
returns   : a0..a7
caller    : t0..t6, a0..a7, ra
callee    : s0..s11, fp, sp
scratch   : tp（并行移动破环）、gp（间接目标保护）
```

限制：

- 参数/返回值 > 8 个：报错。
- `s0..s11` 全部保存：正确但浪费，后续按实际使用裁剪。

---

## 6. 类型层：表示类型，不是源码类型系统

### 6.1 类型语法

```text
b8 b16 b32 b64          8/16/32/64 bit 存储；signed/unsigned 由操作决定
pb8 pb16 pb32 pb64      指向对应宽度的指针（指针本身 64 位）
(ptr T)                 通用指针
(struct S)              结构体值
(array T n)             数组值
value                   带标签的 64 位 Lisp 值
bool / nil              value 的子集
```

### 6.2 slot 类型（A 方案）

```racket
(slot0 (kind local) (repr b64))
(slot1 (kind spill) (repr (ptr (struct point))))
(slot2 (kind captured) (repr value))
```

- `(repr T)` 可省略，默认 `b64`。
- slot 必须是**一个机器字**；`(repr (struct S))` / `(repr (array ...))` 被拒绝。
- `b8/b16/b32` 目前仍占一个 8 字节 slot；精确宽度在 struct field 里生效。

### 6.3 结构体

```racket
(struct point
  (field x b8)
  (field y b64))
```

布局：

```text
x offset 0
y offset 8
size 16
align 8
```

规则：`b8`→1，`b16`→2，`b32`→4，`b64`/指针/`value`→8。
字段不能按值嵌套 struct/array；用 `(ptr ...)`。
字段访问指令 `field-ref/field-set` **还没实现**。

### 6.4 字面值编码

`value` 低 3 位 tag：

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

special = `(code << 3) | 7`：

| 字面值 | 编码 |
|---|---:|
| `#f` | 7 |
| `#t` | 15 |
| `'nil` | 23 |
| `eof` | 31 |

`const` 当前只接受 signed 12-bit 立即数。

注意：原始 `b64` 整数 7/15/23 与 tagged special 机器字相同；
类型标注（`b64` vs `bool/nil/value`）是区分依据，但**目前不做赋值检查**。

### 6.5 类型层现在检查/不检查什么

**检查：**

- repr 语法
- slot 必须是单字
- struct 字段布局/大小/对齐
- 字面值编码 + 12-bit 范围
- 顶层 `(struct ...)` 声明会被抽取

**不检查：**

- vreg 类型传播
- `env-set/env-ref` 的 slot/vreg 类型匹配
- `call` 签名 / arity
- `return` 返回类型
- 指针目标兼容性
- GC pointer map / roots

结论：

> **有表示类型标注和布局，还没有类型检查器。**

---

## 7. 文件清单

### 7.1 稳定/已测试

| 文件 | 作用 |
|---|---|
| `main.rkt` | CLI |
| `compile-asm.rkt` | 两条入口的分派与主链组合 |
| `asm.rkt` | asm 判断、vreg、物理寄存器、terminator |
| `cfg.rkt` | basic block + CFG；call 目标作为可达后继 |
| `branch-opt.rkt` | 不可达块删除、跳到下一块删除 |
| `liveness.rkt` | use/def、不动点；认识 ld/sd 和 call/tailcall/return |
| `interference.rkt` | 递归收集 vreg，建冲突图 |
| `regalloc-graph.rkt` | 图着色；预着色；无 spill |
| `layout.rkt` | label -> 字节地址；branch/jal 偏移 |
| `program.rkt` | 顶层 `(program ...)` |
| `frame.rkt` | frame/slot/heap/env/cont/call/tailcall/return 形式 |
| `repr.rkt` | 表示类型、struct 布局、字面值编码、const 形式 |
| `literal-lower.rkt` | `const` -> `addi` |
| `lower-frame.rkt` | 抽声明、env -> ld/sd、prologue |
| `call-lower.rkt` | 参数并行移动、call/tailcall/return、epilogue |
| `sets.rkt` | 集合工具 |

### 7.2 实验性

| 文件 | 状态 |
|---|---|
| `regalloc-cache.rkt` | 缓存式寄存器分配/spill 实验；有测试，**未接入主路径** |

### 7.3 文档

| 文件 | 内容 |
|---|---|
| `FASM.md` | **新目标**：函数式汇编规范、heap frame、closure、continuation、GC |
| `ARCHITECTURE.md` | 旧的 C-like 三层计划；已降级为 bootstrap/legacy |
| `DESIGN.md` | 原底层算法链；对应纯 asm 路径 |
| `FORMS.md` | 形式规范；有些是预留，不等于已实现 |
| `SKELETON.md` | 阶段模型与不变量 |
| `FUNCTIONAL.md` | 函数式模型、frame/续延、cache 分配实验 |
| `TYPES.md` | 表示类型、struct 布局、字面值编码 |
| `STATUS.md` | 本文：当前真实状态 |

### 7.4 示例与测试

```text
examples/basic-asm.sexpr     纯 vreg asm
examples/frame-asm.sexpr     frame/env/cont/call
examples/typed-frame.sexpr   repr/struct/#f/'nil

test/core-test.rkt           原有后端
test/cache-test.rkt          cache allocator 实验
test/frame-test.rkt          frame/env/cont/call + 递归/尾递归
test/repr-test.rkt           repr/struct/literal
```

当前：`make test` -> **1419 tests passed**。
F-asm demo：`make fasm-demo`。

---

## 8. 关键不变量

1. **声明不是指令。** `frame`/`cont`/`struct` 在 CFG 之前抽走。
2. **伪指令穿过分析。** `call`/`tailcall`/`return` 活到 coloring 之后，
   由 liveness 建模 caller-saved。
3. **vreg 一直保留到 coloring。**
4. **slot 一直保留到 frame lowering。**
5. **label 一直保留到 layout。**
6. **未知形式/指令直接报错**，不静默猜测。
7. **所有中间结果都是可打印 S-expression。**
8. **frame size 16 字节对齐。**
9. **输出确定性**：集合排序、固定字段顺序。
10. **逻辑模型与具体策略分离**：stack/heap policy 只换 lowering，不换形式。

---

## 9. 已知边界与坑

按“最容易误解”排序：

1. **一个 asm 只有一个 frame。** prologue 只插在第一个 label 后；
   其他 label 共享同一张 frame。真正的多函数需要每函数自己的 frame。
2. **frame 路径里裸写 `(jalr x0 ra 0)` 不会走 epilogue。**
   应该写 `(return ...)`。示例里的 callee 故意不用 frame，所以是例外。
3. **`(heap 1 i)` 不可用。** offset 0 是动态 old-fp，不是词法父环境。
4. **续延是 one-shot。** 没有 heap 续延、multi-shot、`call/cc`。
5. **主路径不 spill。** 图着色分不到颜色就报错；
   `regalloc-cache` 只是实验。
6. **callee-saved 全保存。** 正确但慢。
7. **参数/返回值最多 8 个。**
8. **struct 只有布局，没有 field-ref/field-set。**
9. **没有 vreg 类型检查、call 签名、GC roots。**
10. **`const` 只支持 12-bit 立即数。**
11. **`b8/b16/b32` slot 仍占 8 字节**；只有 struct field 精确打包。
12. **最终产物是 S-expression program**，不是机器码，也没有 runtime/GC。
13. **call 目标会作为 CFG 后继。** liveness 会把 callee 的 live-in
    保守地带进 caller 的 out；这是当前简化，不是精确的过程间分析。

---

## 10. 推荐的下一步顺序（新目标）

完整路线见 `FASM.md`。顺序：

1. ~~冻结 F-asm 规范。~~ **已完成**（`FASM.md`）。
2. ~~F-asm 参考解释器（Racket）。~~ **已完成**（`fasm-interp.rkt`）。
3. ~~Scheme core -> F-asm。~~ **已完成原型**（`scheme-core.rkt`）。
4. **GC。** roots = frame 链 + `k` + live 寄存器；先 mark-sweep 或 copying。
5. **`define` / 顶层环境 / 宏 / 多值 / 可变参数。**
6. **F-asm -> RISC-V 后端 + runtime。**
   heap frame 分配、closure、continuation、alloc/GC/print。
7. **自举。** 用 Scheme 写 Scheme 编译器，定点比较。

旧路线的 vreg 类型传播、struct field access、多函数 stack frame
不再是主干；需要时再作为优化或 runtime 内部工具补。

---

## 11. 最后一句话

> 现在是“函数式运行时模型的无类型后端 + 一层表示类型”：
> **值有家、上下文是值、寄存器是缓存**，但具体落地是
> **栈帧 + one-shot 续延 + 图着色**；
> heap 续延、词法 link、spill、GC、类型检查都还在路上。
