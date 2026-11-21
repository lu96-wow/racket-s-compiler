# ir

`ir` 实现 virtual IR 的形状、验证和 CFG 抽边。

```text
resolved program (frontend 输出)
        │
        ▼
shape.rkt     只回答“是不是某个形状”
        │
        ▼
verify.rkt    声明、引用、term、op、asm 边界
        │
        ▼
cfg.rkt       只从 block + term 抽后继 / 前驱 / 可达
        │
        ▼
analysis.rkt  读 vreg 声明、pin/reserve/clobber、代码里出现过的 vreg
        │
        ▼
liveness.rkt  def-use、live-in/out、每条指令的 live-before/after
        │
        ▼
allocate.rkt  liveness -> 干涉图 -> 着色 -> spill；输出 allocation + scratch
        │
        ▼
allocation.rkt 验证 allocation 表 / scratch
        │
        ▼
materialize.rkt virtual IR + allocation -> machine IR
        │
        ▼
verify-machine.rkt 没有 ($ x) / 裸 slot / layout 形状
        │
        ▼
call-plan.rkt  统计 outgoing args / scratch demand
        │
        ▼
frame.rkt     slot -> FP offset / frame size
        │
        ▼
lower.rkt      frame-slot / load/store / arithmetic -> native
        │
        ▼
call-lower.rkt prologue / call sequence / return sequence
```

`scratch.rkt` 提供所有阶段共用的 scratch 形状、去重、func 顶层读取和 pool。

它提供 liveness / 分配生成 / materialize / lower / call-lower；不做 layout-relax / encode。

## 文件

| 文件 | 只关心 |
| --- | --- |
| `shape.rkt` | 类型、vreg 声明、alloc 条目、term、普通 op、asm 条款、物理寄存器、禁止的 machine/control 形状 |
| `verify.rkt` | vregs / alloc / entry / block / term / op / asm；名字已声明；没有 native/slot/label/j/b/C ABI |
| `cfg.rkt` | entry、block 文本顺序、每个 term 的后继、前驱、可达/不可达 |
| `analysis.rkt` | vreg 声明表、pin / reserve / clobber、代码里实际出现过的 vreg |
| `liveness.rkt` | def-use、live-in/out、每条指令的 live-before/after |
| `allocate.rkt` | liveness + 干涉图 + 着色 + spill -> allocation + scratch |
| `allocation.rkt` | allocation 表形状、位置、缺项、address-taken、pin/reserve、scratch |
| `scratch.rkt` | scratch 形状、去重、func 顶层读取、pool |
| `frame.rkt` | slot size/offset、frame size、header/outgoing/alignment |
| `materialize.rkt` | virtual IR + allocation -> machine IR；slot load/store + scratch |
| `verify-machine.rkt` | machine IR：没有 vreg / 裸 slot / layout 形状；frame / scratch / frame-slot 合法 |
| `lower.rkt` | const/copy/算术/load/store/addr(frame) -> native；不新增 vreg |
| `li.rkt` | `riscv-help` li 展开 -> `(native xN)` machine IR |
| `call-plan.rkt` | 最大参数、outgoing size、scratch demand |
| `call-lower.rkt` | prologue / 参数写 outgoing area / call-target / return epilogue |

共享的 `form?` / `chain?` / `vreg?` / `native?` / `global-ref?` 在
[`../core/sexp.rkt`](../core/sexp.rkt)。

## verify-virtual

入口：

```racket
(require "ir/verify.rkt")

(verify-virtual program)        ; (listof func) -> 原样返回
(verify-virtual-func func)      ; 单个 func -> 原样返回
```

检查：

- 顶层只有 `func`。`data` / `raw` 走别的路径，不进入 virtual IR。
- 每个函数恰好一个 `(vregs ...)`、至多一个 `(alloc ...)`、恰好一个 `(entry ...)`。
- vreg 条目是 `(($ name) type option ...)`；类型和 option 合法；没有重复。
- `alloc` 只允许 `reserve` / `pin` / `clobber`；`pin` 的 vreg 必须已声明；
  `(address-taken)` 的 vreg 不能 `pin`；同一 vreg 不能 pin 到两个寄存器。
- block 名是函数局部 symbol；不能重复；每个 block 恰好一个 `term`，且在最后。
- `jump` / `branch` 的目标必须是同函数已声明 block。
- 普通 op 只使用 `virtual-op-head?` 里的操作；目标必须是 vreg；操作数是
  integer / vreg / `(global chain)`；vreg 必须已声明。
- condition 只接受 integer 或 vreg；全局地址必须先 `addr` 进 vreg。
- `addr` 的源只能是 `(global chain)` 或 `(address-taken)` vreg。
- `load` / `store` 的 offset 是整数，type 合法。
- 普通 op 里没有 `(native ...)` / `(slot ...)` / `(frame ...)` /
  `label` / `j` / `b` / C ABI 名字。
- `asm` 是一个特殊 op：必须包含 `inputs` / `outputs` / `clobber` / `code`；
  bindings 是 `((vreg) (native xN))`；`code` 内不能有 `($ ...)` / `(global ...)` /
  `(term ...)`，物理寄存器必须是 `x0..x31`。
- `(native ...)` 只接受 `x0..x31`；`a0` / `ra` / `sp` 等 ABI 别名被拒绝。

不检查：

- CFG 是否所有 block 都可达（`cfg.rkt` 提供 `unreachable-blocks`）；
- 未使用 vreg / 死代码；
- 寄存器分配；
- inline asm 内部的分支目标是否闭合（属于 asm/layout 的检查）。

## CFG

```racket
(require "ir/cfg.rkt")

(build-cfg func)          ; -> cfg
(build-program-cfg prog)  ; -> (listof cfg)

(cfg-name c)
(cfg-entry c)
(cfg-blocks c)            ; 文本顺序
(cfg-successors c)        ; hash block -> (listof block)
(cfg-predecessors c)      ; hash block -> (listof block)

(reachable-blocks c)      ; 发现顺序
(unreachable-blocks c)    ; 保持文本顺序
(cfg-all-reachable? c)
```

CFG 层只抽边，不删不可达 block，也不合并空 block。那些是后续 pass。

## liveness

入口：

```racket
(require "ir/liveness.rkt")

(analyze-liveness func)   ; -> liveness
;; liveness-live-in  : hash block -> set(vreg)
;; liveness-live-out : hash block -> set(vreg)
;; liveness-instructions : hash block -> (listof instruction)
```

每条 `instruction` 提供：

```racket
(instruction-form ins)         ; op 或 term
(instruction-defs ins)         ; (listof vreg)
(instruction-uses ins)         ; (listof vreg)
(instruction-live-before ins)  ; set(vreg)
(instruction-live-after ins)   ; set(vreg)
```

规则：

- block 的 use 是 upward-exposed use：第一次定义之前的 use；
- block 的 def 是本 block 内所有 def 的并集；
- `live-in = use ∪ (live-out - def)`；
- CFG 后继来自 `cfg.rkt`；
- `asm` 的 uses 是 `inputs`，defs 是 `outputs`；
- 不分配、不 spill、不改 IR。

## allocate

入口：

```racket
(require "ir/allocate.rkt")

(allocate-func func
               #:scratch-budget 0
               #:forbidden '())
;; => (values allocation scratch)
```

第一版规则：

- 先跑 `verify-virtual-func`；
- 用 `liveness.rkt` 建干涉图；
- 同时 live 的 vreg 互相干涉；
- `(address-taken)` -> `(slot n)`；
- `pin` 固定到指定物理寄存器；互相干涉的两个 pin 不能使用同一寄存器；
- `reserve` / `clobber` / `#:forbidden` 的寄存器不分配给普通 vreg；
- `#:forbidden` 适合传入 runtime contract 占用的寄存器；
- x0 永远不分配；不能 pin 到 x0；
- `#:scratch-budget` 个 scratch 先从可用寄存器里预留，普通 vreg 不能占用；
- 着色顺序是度数降序、声明顺序升序；
- 没有可用颜色的 vreg spill 到唯一 slot；
- 输出前自检 `verify-allocation`。

当前不做：

- coalescing；
- slot sharing；
- 调用点感知的 liveness；
- scratch budget 自动反馈（驱动传预算）。

## allocation 验证

入口：

```racket
(require "ir/allocation.rkt")

(verify-allocation func allocation)          ; -> allocation
(verify-allocation func allocation scratch)  ; scratch 可选
```

形状：

```scheme
(allocation
  (($ a) (native x10))
  (($ b) (slot 0)))

(scratch (native x5))          ; 单独返回，不放进 allocation 表
```

检查：

- 条目是二元 proper list `(vreg location)`；location 是 `(native xN)` 或 `(slot n)`。
- key 必须是已声明 vreg；不能重复。
- 代码里出现过的 vreg 必须有条目。
- `(address-taken)` 的 vreg 必须有条目，而且必须是 `(slot n)`。
- `pin` 的 vreg 如果分配了，必须落在指定物理寄存器。
- 普通 vreg 不能落进 `reserve` 的寄存器；显式 pin 到该寄存器除外。
- `scratch` 如果传入，必须是 `(scratch (native xN))`；同一个寄存器不能重复列出。
- `clobber` 是函数级保守并集；分配器会避开这些寄存器。

不检查：

- allocation 是否最优；
- spill 策略；
- scratch 是否被 reserve；
- materialize 后的 load/store。

查表：

```racket
(allocation-location allocation '($ a))  ; => (native x10) 或 #f
(allocation-table allocation)             ; => hash
```

## frame-layout

入口：

```racket
(require "ir/frame.rkt")

(frame-layout func allocation
              #:xlen 64
              #:header-size 16
              #:outgoing-size 0
              #:frame-align 16)
;; => frame
```

输出：

```scheme
(frame
  (size 48)
  (header 16)
  (outgoing 0)
  (align 16)
  (slots
    (slot 0 (offset 17) (size 1) (align 1))
    (slot 1 (offset 40) (size 8) (align 16))))
```

规则：

- slot offset 是 FP 到 slot 低地址的距离：地址 = `FP - offset`；
- slot 按 slot index 升序放置；
- 多个 vreg 共享一个 slot 时取最大 size/align；
- size/align 来自 vreg 类型和 `(align n)`；
- `(ptr)` 的大小由 `#:xlen` 决定，默认 64；
- header 默认 saved RA + saved old FP；可以加大以包含 callee-saved 保存区；
- outgoing args 在帧底部；
- frame size 按 `#:frame-align` 对齐。

查表：

```racket
(frame-size frame)
(frame-slots frame)
(frame-slot-offset frame 0)  ; => 17 或 #f
```

内存模型和 runtime contract 见 [`../MEMORY.md`](../MEMORY.md)。

## materialize

入口：

```racket
(require "ir/materialize.rkt")

(materialize-func func allocation #:scratch scratch-regs)
;; => machine func
```

第一版规则：

- 寄存器位置的 vreg -> `(native xN)`；
- slot 位置的 vreg -> `load` / `store` + scratch；
- `(addr dst ($ x))` -> `(addr machine-dst (frame-slot n))`；
- `load` / `store` / 条件里的 slot 操作数先 load 到 scratch；
- dst 在 slot 时，先算到 scratch，再 store；
- call 的 slot 参数先 load 到 scratch；
- call 的 slot 返回值在 call 后 store；能复用参数 scratch 就复用；
- return 的 slot 操作数先 load 到 scratch；
- inline asm：input/output parallel move，code -> `(asm-code ...)`；
- block / term 形状不变；
- 输出里没有 `($ x)`；
- output 里保留 `(scratch (native xN) ...)`，不再有 `vregs` / `alloc`。

asm 的 clobber 并集会被分配器当作函数级不可用寄存器。materialize 会拒绝
clobber 与 input/output 目标重叠、两个不同 vreg 绑同一目标寄存器等情况。

call-lower 选自己的 scratch 时会避开已经放着 call 参数的寄存器，避免覆盖
materialize 刚 load 的参数。

## lower-ops

入口：

```racket
(require "ir/lower.rkt")

(lower-func machine-func frame
            #:xlen 64
            #:fp '(native x8)
            #:scratch scratch-regs)
;; => selected machine func
```

处理：

- `const` / `copy` -> `li` / `addi`；
- 二元算术 -> native ALU + 立即数形式；
- `load` / `store` -> `lb/lbu/lh/lhu/lw/lwu/ld` / `sb/sh/sw/sd`；
- `frame-slot` -> `FP - offset`；
- `addr(frame-slot)` -> `addi` 或 `li` + `add`；
- 大立即数 / 超范围 offset -> scratch + `li`。

native 顺序：

```scheme
(ld  (native x11) (native x10) 0)   ; load: rd rs1 imm
(sd  0 (native x10) (native x11))   ; store: imm rs1 rs2
```

不处理：

- `call` / `return` / `asm`；
- `addr(global ...)`；
- 条件到 b 指令的映射；
- b/j/island。

详见 [`../LOWER.md`](../LOWER.md)。

## verify-machine

入口：

```racket
(require "ir/verify-machine.rkt")

(verify-machine program)        ; (listof machine func) -> 原样返回
(verify-machine-func func)      ; 单个 machine func -> 原样返回
```

检查：

- 顶层只有 `func`；`vregs` / `alloc` / `allocation` 不能出现。
- 没有 `($ x)`。
- 值操作数是 `(native xN)`、整数、`(global chain)`；内存地址可以用
  `(frame-slot n)`。
- 裸 `(slot n)` 不是合法值操作数。
- `(native ...)` 只接受 `x0..x31`；ABI 别名直接拒绝。
- `frame` 形状合法；有 frame 时，每个 `(frame-slot n)` 都必须在 frame 里。
- `scratch` 形状合法；同一个寄存器不能重复。
- `entry` 必须存在并指向已声明 block；block 名不能重复。
- 每个 block 恰好一个 term，且在最后。
- term 只接受 `jump` / `branch` / `return` / `trap`；目标 block 必须已声明。
- 机器函数里没有 `label` / `j` / `jal` / `jalr` / `b` 指令；`asm.code` / `raw` 例外。
- `call-target` 只能是 `(call-target (global chain))`。
- `asm` 如果出现在 machine IR，bindings 必须已经是 `(native xN)`。

不检查：

- 指令选择是否正确；
- 寄存器分配是否最优；
- 布局 / island / 编码；
- `raw`。

## call / return lowering

入口：

```racket
(require "ir/call-plan.rkt")
(require "ir/call-lower.rkt")

(plan-calls func #:xlen 64)
;; => (call-plan (max-args n) (outgoing-size bytes) (scratch-demand n))

(lower-calls func frame #:xlen 64 #:scratch scratch-regs)
;; => func with prologue / call-target / return epilogue
```

规则：

- 参数全部写 caller 的 outgoing area；
- `SP + i*word` 写参数，`FP + i*word` 读参数；
- prologue 用 scratch 保存 old FP；
- `(call dst (global f) arg ...)` -> 写参数 + `(call-target (global f))` + 结果移动；
- `(term (return operand ...))` -> 返回值到 x10 + epilogue + `(term (return))`；
- `(call-target ...)` / `(term (return))` 的最终 jal/jalr 由 layout-relax 选；
- 第一版最多 1 个返回值；
- 第一版无 callee-saved。

详见 [`../CALL.md`](../CALL.md)。

## 已定的验证约定

| 问题 | 决定 |
| --- | --- |
| `vregs` 是否必须写 | 必须写；可以写成 `(vregs)` |
| 普通 op 的 `global` 操作数 | 允许；condition 里不允许，先 `addr` |
| `native` 的写法 | 只允许 `x0..x31`；ABI 别名直接拒绝 |
| `asm` 条款 | `inputs` / `outputs` / `clobber` / `code` 四个都必须在，顺序不限 |
| `asm.code` | 封闭 machine 块；禁止 vreg / global / term |
| `address-taken` + `pin` | 冲突，verify 直接报错 |
| 同一 vreg 多次 `pin` | 同一寄存器幂等；不同寄存器报错 |
| block 可达性 | 不在 verify 报错；由 CFG 层报告不可达 block |
| allocation 缺项 | 代码里出现过的 vreg 必须有条目；未使用的已声明 vreg 可以没有 |
| `address-taken` + allocation | 必须是 `(slot n)`，不能是 `(native xN)` |
| `pin` + allocation | 分配了就必须落在指定寄存器 |
| `reserve` + allocation | 普通 vreg 不能落进保留寄存器；显式 pin 可以 |
| `scratch` | 单独输出，不是 allocation 条目；可以写 `(scratch (native xN) ...)` 多个 |
| frame slot | allocation 的 `(slot n)` 由 frame-layout 变成 `FP - offset` |
| 多个 vreg 共享 slot | 允许；frame-layout 取最大 size/align |

## 测试

```bash
cd riscv/riscv-core
raco test test/verify-test.rkt test/cfg-test.rkt test/liveness-test.rkt test/allocation-test.rkt test/allocate-test.rkt test/frame-test.rkt test/materialize-test.rkt test/lower-test.rkt test/call-plan-test.rkt test/call-lower-test.rkt test/verify-machine-test.rkt test/stack-call-test.rkt
```
