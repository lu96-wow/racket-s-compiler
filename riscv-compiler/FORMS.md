> **注意**：本文件包含早期 C/stack policy 形式。
> 新目标见 `FASM.md`：`frame/env/cont/call` 形式保留，
> 但 `policy (frame stack)`、SysV ABI、callee-saved 等只是 bootstrap，
> 不是 F-asm 的目标语义。

# riscv-compiler 显式 S-expression 形式

> 本文只定**形式**，不实现。
> 参考 LLVM `MachineInstr` / `MachineFrameInfo` / `CallingConv` / `gc.statepoint`
> 和 GCC RTL 的 `(reg)` / `(mem)` / virtual stack slot / `CALL_USED_REGISTERS`，
> 但保持本项目风格：tag 开头、扁平、可打印、符号世界与具体世界分离。

---

## 0. 约束

1. 每个 form 的第一个元素是 **tag**。
2. 每个阶段 = **一张表 + 一次统一 rewrite**，不隐藏状态。
3. 符号世界：`vreg` / `slot` / `label` / `preg`；具体世界：`integer` offset/address。
4. 每个阶段只引入自己拥有的具体化，下游不猜。
5. 未知 tag / 未知指令 -> `error`。
6. 所有字段按固定顺序输出，空字段写 `()`，保证 `equal?` 稳定、可测试。
7. `layout` 之前，所有伪指令/伪形式必须被消除。

---

## 1. 词法

```text
vreg   ::= v<number>            ; v0, v1, ...
slot   ::= slot<number>         ; slot0, slot1, ...
label  ::= symbol               ; main, L0, ...
preg   ::= x0 | ra | sp | gp | tp
         | t0..t6 | s0..s11 | a0..a7
```

标签（tag）保留字，不能当指令：

```text
func program globals global
policy callconv
locations location
slots slot frame heap-frame
asm label
safepoint roots context capture-context
```

---

## 2. 顶层层级

### 2.1 program

```racket
(program
  (globals
    (global g0 (size 8) (align 8)))
  (func ...)
  (func ...))
```

- `(globals)` 为空时保留。
- 单函数路径可以直接传 `(func ...)`，或继续用现有的 `(asm ...)`。

### 2.2 func

```racket
(func main
  (policy ...)
  (callconv ...)
  (locations ...)
  (slots ...)
  (frame ...)
  (asm
    (label main)
    ...)
  (roots ...))
```

- `main` 是函数名；`(label main)` 是入口 label，两者不合并。
- 字段顺序固定；未到的阶段用 `()` 占位。
- `(asm ...)` 就是现在底层链的输入/输出形状，不改变。

---

## 3. location：变量在哪

location **只在指令选择边界和元数据里出现**；指令操作数仍然是裸 `vreg`/`preg`。

```racket
loc ::= (reg vreg)              ; 分配前
      | (reg preg)              ; 分配后
      | (stack slot)            ; 机器栈
      | (heap depth index)      ; 语言堆：沿 frame 链走 depth 层，取第 index 槽
      | (global name)           ; 全局符号
      | (imm integer)           ; 常量
```

```racket
(locations
  ((x . (reg v0))
   (y . (stack slot2))
   (f . (heap 2 1))
   (g . (global g0))))
```

对应关系：

| 本项目 | LLVM | GCC RTL |
| --- | --- | --- |
| `(reg v0)` | virtual register | `(reg:SI 42)` 伪寄存器 |
| `(reg t0)` | physical register | `(reg:SI 5)` 硬寄存器 |
| `(stack slot2)` | frame index (FI) | virtual stack slot / `(mem (plus fp const))` |
| `(heap 2 1)` | GC 语言里的 env 访问，无直接对应 | display / 链接帧的 `(mem (plus ...))` |
| `(global g0)` | `GlobalValue` | `SYMBOL_REF` |

---

## 4. slot 与 frame

### 4.1 slot 声明

slot 是**符号**，大小/对齐/用途显式写出：

```racket
(slots
  (slot slot0 (size 8) (align 8) (kind spill))
  (slot slot1 (size 8) (align 8) (kind local))
  (slot slot2 (size 8) (align 8) (kind outgoing)))
```

`kind`：

```text
spill      ; 寄存器溢出槽
local      ; 取地址/不可放寄存器的局部变量
outgoing   ; 调用时传参用的栈槽
saved      ; 保存 callee-saved / ra
```

对应 LLVM `MachineFrameInfo::StackObject {Size, Alignment, isSpillSlot}`、
GCC 的 virtual stack slot。

### 4.2 stack frame

```racket
(frame
  (base sp)                                  ; sp | fp
  (size 48)
  (offsets ((slot0 . -8) (slot1 . -16)))
  (saved   ((ra . -24) (s0 . -32)))
  (outgoing ()))
```

- `size` 是具体整数，`offsets` 是 slot -> integer。
- `saved` 是 callee-saved 的落点，也是 slot，只是这里直接写 offset。
- `outgoing` 预留给 >8 个参数的调用。
- frame 是**机器栈**；与语言堆无关。

### 4.3 heap frame（预留给 heap policy）

```racket
(heap-frame H0
  (size 24)
  (offsets ((0 . 0) (1 . 8)))
  (link (reg vframe)))       ; 指向父 frame，用于 (heap depth index)
```

- `(heap depth index)` 的 `depth` 就是沿 `link` 走几层。
- 该形式先只记录，不实现。

---

## 5. policy 与 callconv

### 5.1 policy

policy 是**编译期参数**，决定后端用哪套 lowering，不改变前端：

```racket
(policy
  (frame stack)            ; stack | heap
  (callconv riscv-sysv)
  (gc none)                ; none | precise
  (tailcall optional))     ; optional | required
```

- C 模型：`(frame stack) (gc none) (tailcall optional)`
- Scheme 模型：`(frame heap) (gc precise) (tailcall required)`
- 同一份 `(asm ...)` 可以配不同 policy 跑同一串 pass。

### 5.2 callconv

```racket
(callconv
  (name riscv-sysv)
  (args a0 a1 a2 a3 a4 a5 a6 a7)
  (returns a0 a1)
  (caller-saved t0 t1 t2 t3 t4 t5 t6
                a0 a1 a2 a3 a4 a5 a6 a7)
  (callee-saved s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11)
  (reserved x0 ra sp gp tp))
```

- `ra` 由调用点隐式 def，prologue/epilogue 负责保存。
- 当前 `physical-pool` 的 `t*` 和 `a1..a7` 只有在没有跨函数调用时才安全；
  callconv 就是把这个前提显式化。
- liveness 处理 `(call ...)` 时，按 `caller-saved` 生成隐式 def。
  对应 LLVM 的 implicit def / GCC 的 `CALL_USED_REGISTERS`。

---

## 6. 伪指令

伪指令和真实指令同一位置，用连字符名字区分：

```racket
(copy dst src)                       ; 寄存器到寄存器，可合并
(load-slot dst slot)                 ; dst <- slot
(store-slot slot src)                ; slot <- src
(call target (args v1 v2) (rets v3))
(tailcall target (args v1 v2))
(return (v1 v2))
(safepoint S0)
(capture-context C0)
```

规则：

- `(copy ...)` 对应 LLVM `COPY`、GCC `(set (reg) (reg))`。
- `(load-slot ...)` / `(store-slot ...)` 对应 LLVM 的 spill `load`/`store`、
  GCC `(set (reg) (mem ...))` / `(set (mem ...) (reg))`。
- `slot` 在这里是**裸符号**，因为操作数位置已经由指令确定类型；
  只有 location 值里才写 `(stack slot0)`。
- `(call ...)` 不是 terminator；`(tailcall ...)`、`(return ...)` 是 terminator。
- `(return (v1 v2))` 里的列表是**值列表**，不是子指令。
- `(safepoint S0)` 是 no-op 标记，不能被 branch-opt 删除。

liveness 需要认识这些伪指令：

| 指令 | use | def |
| --- | --- | --- |
| `(copy d s)` | `s` | `d` |
| `(load-slot d slot)` | `()` | `d` |
| `(store-slot slot s)` | `s` | `()` |
| `(call f (args ...) (rets ...))` | args | rets + caller-saved |
| `(tailcall f (args ...))` | args | caller-saved |
| `(return (vals))` | vals | `()` |
| `(safepoint S)` | `()` | `()` |
| `(capture-context C)` | 所有 live + `ra` + `fp` | caller-saved |

---

## 7. safepoint / roots

```racket
(safepoint S0)
```

```racket
(roots
  (S0 (live (reg t0)
            (stack slot1)
            (heap 1 0))))
```

- `roots` 由 `safepoint` + liveness + regmap + frame 生成。
- 语义：在 `S0` 处，GC 必须把这些位置当根扫描。
- `(stack slot1)` 在 frame 之后有 offset，运行时用 frame 表换算。
- C 模型 `(gc none)` 时 `roots` 为空。
- 对应 LLVM `STACKMAP` / `gc.statepoint`、GCC `-fvar-tracking` 的变量位置表。

---

## 8. context（预留）

context = safepoint + frame 快照，不引入新原语：

```racket
(capture-context C0)
```

```racket
(context C0
  (resume Lret)
  (frame (reg fp))
  (live (reg t0)
        (stack slot1)))
```

- `(capture-context C0)` 是伪指令，发生时把所有 live location 物化。
- `(context ...)` 表记录恢复执行所需的状态。
- 绿色线程/协程 = 交换 `sp` + `frame` + `live`。
- `call/cc` = 快照 `roots` + frame 链。
- 普通 C/Scheme 不需要，先只定形式。

---

## 9. 阶段契约

```text
select
  -> func + asm(vreg, copy/call/return/safepoint)
spill
  -> asm(vreg, load-slot/store-slot) + slots(kind spill)
call-lower
  -> asm(real call insns) + saved/outgoing 元数据
frame
  -> frame(size, offsets, saved, outgoing)
emit-prologue
  -> asm(prologue/epilogue 已展开)
roots
  -> roots 表
layout
  -> 数值 code
```

| form | 引入阶段 | 消除/具体化阶段 | 是否进 asm |
| --- | --- | --- | --- |
| `(policy ...)` | 输入 | 贯穿 | 否 |
| `(callconv ...)` | 输入 | call-lower | 否 |
| `(locations ...)` | select | location-lower | 否 |
| `(slots ...)` | select/spill | frame | 否 |
| `(load-slot ...)` | spill | frame | 是 |
| `(store-slot ...)` | spill | frame | 是 |
| `(copy ...)` | select | coalesce/lower | 是 |
| `(call ...)` | select | call-lower | 是 |
| `(tailcall ...)` | select | call-lower | 是 |
| `(return ...)` | select | call-lower | 是 |
| `(safepoint ...)` | select | roots | 是 |
| `(frame ...)` | frame | layout | 否 |
| `(roots ...)` | roots | encode | 否 |
| `(capture-context ...)` | 预留 | 预留 | 是 |

**顺序约束**：

1. spill 之后必须重建 CFG / liveness / interference，再着色；这是不动点。
2. call-lower 必须在着色之后，因为要知道哪些 `s*` 真被用了。
3. frame 必须在 spill 和 call-lower 之后，因为 frame 大小依赖 spill 槽、
   saved 集合、outgoing 槽。
4. emit-prologue 在 frame 之后，因为要用具体 offset。
5. roots 在 frame 之后，因为 `(stack slot)` 需要 offset。
6. layout 最后。

---

## 10. 例子：同一程序穿过各阶段

### 10.1 select 输出

```racket
(func add
  (policy (frame stack) (callconv riscv-sysv) (gc none) (tailcall optional))
  (callconv ...)
  (locations ((x . (reg v0)) (y . (reg v1))))
  (slots ())
  (frame ())
  (asm
    (label main)
    (addi v0 x0 1)
    (addi v1 x0 2)
    (add v2 v0 v1)
    (return (v2)))
  (roots ()))
```

### 10.2 spill（假设 v0 分不到色）

```racket
  (slots
    (slot slot0 (size 8) (align 8) (kind spill)))
  (asm
    (label main)
    (addi v3 x0 1)
    (store-slot slot0 v3)
    (addi v1 x0 2)
    (load-slot v4 slot0)
    (add v2 v4 v1)
    (return (v2)))
```

### 10.3 call-lower

```racket
  (asm
    ...
    (addi a0 v2 0)
    (jalr x0 ra 0))
```

### 10.4 frame

```racket
  (frame
    (base sp)
    (size 16)
    (offsets ((slot0 . -8)))
    (saved ())
    (outgoing ()))
```

### 10.5 emit-prologue

```racket
  (asm
    (addi sp sp -16)
    (sd ra 8 sp)
    ...
    (ld ra 8 sp)
    (addi sp sp 16)
    (jalr x0 ra 0))
```

### 10.6 layout

```racket
(program
  (globals)
  (func add
    (policy ...)
    (frame ...)
    (asm
      (label main)
      ...
      (jalr x0 ra 0))
    (roots ())))
```

---

## 11. 不变量

1. `layout` 之前不允许出现 `load-slot` / `store-slot` / `call` / `return` /
   `tailcall` / `safepoint` / `capture-context`。
2. `slot` 只在 frame 之后变成整数 offset。
3. `vreg` 只在 coloring 之后变成 `preg`。
4. 任何一个跨 `(call ...)` 的 live 值，必须和所有 caller-saved 冲突；
   由 liveness 的隐式 def 保证，而不是靠人记得。
5. `(safepoint S)` 处的每个 live location 必须能被 `(roots S ...)` 完整表达。
6. `(policy ...)` 和 `(callconv ...)` 只影响 lowering 选择，不影响前端产出。
7. 空字段写 `()`，字段顺序固定。

---

## 12. 待定

| # | 问题 | 建议默认 |
| --- | --- | --- |
| 1 | slot 用 `slot0` 还是 `(slot 0)` | 符号 `slot0`，和 `v0` 一致 |
| 2 | policy 放 func 里还是 CLI 参数 | 放 func 元数据，CLI 只覆盖 |
| 3 | call-clobber 内联还是查 callconv | 查 callconv，避免每条 call 重复 |
| 4 | `(return ...)` 用值列表还是扁平 | 值列表 `(return (v1 v2))` |
| 5 | `(func ... (asm ...))` 嵌套还是扁平 | 嵌套，`asm` 保持独立阶段 |
| 6 | `(heap depth index)` 是否够表达闭包 | 先够；链式 frame 用 `link` |
