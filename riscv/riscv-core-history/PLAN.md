# 一步一步验证

每一步只引入一种新能力。前一步通过之前，不进入下一步。

测试数据放在 [`examples/`](examples/)，测试代码放在 `test/`。
当前 `test/` 下有 `frontend-test.rkt`、`verify-test.rkt`、`cfg-test.rkt`、`liveness-test.rkt`、`allocation-test.rkt`、`allocate-test.rkt`、`frame-test.rkt`、`materialize-test.rkt`、`lower-test.rkt`、`call-plan-test.rkt`、`call-lower-test.rkt`、`verify-machine-test.rkt`、`layout-plan-test.rkt`、`layout-relax-test.rkt`、`layout-program-test.rkt`、`encode-test.rkt`、`stack-call-test.rkt`、`data-test.rkt`、`data-layout-test.rkt`、`raw-test.rkt`、`asm-code-test.rkt`、`layout-islands-test.rkt`。

设计边界、已修冲突和未定点见 [`REVIEW.md`](REVIEW.md)。
碰到未定点时，先把决定写进 `REVIEW.md`，再实现。

---

## Step 0：形状与 list 操作

**目标**：证明所有东西都能用 `match` / `assoc` / `equal?` 判断，不做字符串解析。

验收：

- `($ a)` 是二元 list，head 是 symbol `$`。
- `(native x10)` 是二元 list，head 是 symbol `native`。
- `(global (d table))` 是二元 list，head 是 symbol `global`。
- `($ a)` 和 `(native x10)` 不靠 `symbol->string` 区分。
- `(($ a) (b8))` 和 `(($ a) (native x10))` 都是二元 proper list。
- 不出现 dotted pair。

示例：`examples/minimal.rkt`。

> 当前状态：共享形状在 `core/sexp.rkt`，virtual IR 形状在 `ir/shape.rkt`；
> 由 `test/verify-test.rkt` 覆盖。

---

## Step 1：virtual IR 验证

输入：`examples/minimal.rkt` 的 `minimal-virtual`。

检查：

- 输入是 resolved virtual program；顶层只有 `func`（`raw` 走 machine 路径）。
- `vregs` 每个条目是 `((vreg) type option ...)`。
- 每个 `($ x)` 都已声明，没有重复。
- 每个 block 恰好一个 term，且在最后。
- term 的后继都是同函数 block。
- 没有跨函数边。
- 普通代码 op 里没有 `(native ...)` / `(slot ...)`；`asm` 的
  inputs/outputs/clobber 和 `asm.code` 除外。
- 没有 `j` / `b` / `label`；`asm.code` 除外（`raw` 不进入 virtual IR）。
- 没有 C ABI 名字（`a0` / `ra` / `sp` 等）。

产出：一份验证通过的 virtual program。

> 当前状态：`ir/verify.rkt` 已实现；`test/verify-test.rkt` 覆盖合法程序和主要错误。
> `(native ...)` 只接受 `x0..x31`；`asm` 四个条款都必须在。

---

## Step 2：CFG

输入：Step 1 的 virtual program。

检查：

- `entry` 可达。
- 每个 block 的 successors 来自 term：
  - `jump`：1 条；
  - `branch`：2 条；
  - `return` / `trap`：0 条。
- 不可达 block 可以被 DCE 删除。
- 空 block 合并只在 CFG 层做，不改 op 内容。

验收例子：

- `examples/branch.rkt`：`b0` 有两条边，`b1` 一条，`b2` 零条。
- 删除不可达 block 后，所有后继仍然存在。

> 当前状态：`ir/cfg.rkt` 已实现抽边、前驱、可达/不可达；DCE 和空 block 合并
> 还没有实现。`test/cfg-test.rkt` 覆盖 branch / 循环 / 不可达 block。

---

## Step 3：allocation 形状

输入：Step 1 的 `vregs` + 一个测试用 allocation。

```scheme
(allocation
  (($ a) (native x10))
  (($ b) (slot 0))
  (($ t) (native x11)))
```

检查：

- 每个条目是 `(vreg location)` 二元 proper list。
- key 是已声明 vreg。
- location 是 `(native xN)` 或 `(slot n)`。
- 每个被使用的 vreg 恰好一个条目。
- 没有重复 key。
- `(address-taken)` 的 vreg 分配到 `(slot n)`。
- 没有 `#f` 占位。
- scratch 是单独的 `(scratch (native xN))`，不是 vreg 条目。
- 查找用 `(assoc ...)` / `cadr`，不用字符串。

验收：

```racket
(cadr (assoc '($ a) (cdr allocation)))  ; => (native x10)
(cadr (assoc '($ b) (cdr allocation)))  ; => (slot 0)
```

> 当前状态：`ir/allocation.rkt` 已实现；`ir/analysis.rkt` 提供声明、pin/reserve/clobber
> 和 used-vreg 收集。`test/allocation-test.rkt` 覆盖缺项、address-taken、pin、
> reserve、scratch。scratch 的共享形状 / 去重 / pool 在 `ir/scratch.rkt`；
> 同一 scratch 重复列出会报错。生成表的分配器在 Step 3.1。

---

## Step 3.1：liveness + 分配生成

输入：verified func。

liveness：

- def-use 覆盖 `const` / `copy` / `load` / `store` / `addr` / `call` /
  二元算术 / `asm` / term；
- block use 是 upward-exposed use；
- `live-in = use ∪ (live-out - def)`；
- 输出每个 block 的 live-in / live-out 和每条指令的 live-before / after。

分配：

- 同时 live 的 vreg 互相干涉；
- `(address-taken)` -> `(slot n)`；
- `pin` 固定到物理寄存器；不能 pin x0；互相干涉的 pin 不能同寄存器；
- `reserve` / `clobber` / `#:forbidden` 不分配给普通 vreg；
- scratch 从可用寄存器预留，普通 vreg 不能占用；
- 没有可用颜色就 spill 到唯一 slot；
- 输出 `(values allocation scratch)`，并自检 `verify-allocation`。

验收：

- minimal / stack-local 分配后能直接 materialize / frame-layout / lower；
- spill 函数用 scratch 完成 slot 读写；
- pin、reserve、clobber、并干涉 pin、x0 pin 有明确错误；
- 输出 machine IR 通过 `verify-machine`。

> 当前状态：`ir/liveness.rkt` 和 `ir/allocate.rkt` 已实现；
> `test/liveness-test.rkt` 覆盖 def-use / live-in/out / asm；
> `test/allocate-test.rkt` 覆盖着色、pin、reserve、clobber、spill 和完整 pipeline。
> 当前不做 coalescing、slot sharing、调用点感知 liveness、scratch budget 自动反馈。

---

## Step 3.5：frame-layout

输入：verified func + allocation + call-plan 的 `outgoing-size`。

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

检查：

- 只有 allocation 里的 `(slot n)` 产生 frame slot；
- `(address-taken)` 的 vreg 必须在 slot；
- slot size/align 来自 vreg 类型和 `(align n)`；
- 多个 vreg 共享 slot 时取最大 size/align；
- offset 是 FP 到 slot 低地址的距离；
- frame size 包含 header、slots、outgoing args 和 padding。

> 当前状态：`ir/frame.rkt` 已实现；`test/frame-test.rkt` 覆盖对齐、共享 slot、
> outgoing args、xlen、address-taken 错误。内存模型见 [`MEMORY.md`](MEMORY.md)。

---

## Step 4：materialize

输入：virtual IR + allocation。

输出：machine IR。

检查：

- 所有 `($ x)` 都被替换：
  - 寄存器位置的，变成 `(native xN)`；
  - slot 位置的，变成 load/store + scratch。
- machine IR 中没有 `($ x)`。
- block / term 形状不变。
- 没有新增虚拟寄存器。
- spill 使用的 scratch 来自 allocation，不自己挑。
- 不出现 C ABI 名字。

验收例子：

```scheme
;; virtual
(add ($ t) ($ a) ($ b))

;; allocation
(($ a) (native x10))
(($ b) (native x11))
(($ t) (native x12))

;; machine
(add (native x12) (native x10) (native x11))
```

如果 `($ b)` 分配在 `(slot 0)`：

```scheme
(load (native x5) (frame-slot 0) 0 (b64))
(add (native x12) (native x10) (native x5))
```

其中 `(native x5)` 来自 `scratch`，不是 materialize 自己选的。

> stack-first 约定：`(addr ($ p) ($ x))` 在 materialize 后写成
> `(addr (native xP) (frame-slot n))`，不存在隐式 local load/store。
> 具体见 [`MEMORY.md`](MEMORY.md)。

> 当前状态：`ir/materialize.rkt` 已实现寄存器 / slot / addr / branch / load / store，
> 以及 call slot 参数 / call slot 返回值 / return slot 操作数。
> `test/materialize-test.rkt` 覆盖 scratch、slot dst、addr、branch、call/return slot 和错误。
> inline `asm` 暂时显式报错。materialize 之后的 machine IR 可以用
> `ir/verify-machine.rkt` 检查。

---

## Step 4.5：lower-ops

输入：materialize + call-plan + frame-layout 之后的 machine IR。

检查：

- `load` / `store` 选择具体的 native 形式（`lb` / `lbu` / `sb` 等）。
- 算术 op 选择 `add` / `addi` / `li` + `add` 等具体形式。
- `const` / 超范围立即数如果会新增 vreg，已经在 allocate 前展开。
- 这一步不新增虚拟寄存器。
- `addr` / 远形式不在这里做；它们依赖最终地址，留给 layout。

输出：selected machine IR。

> 当前状态：`ir/lower.rkt` 已实现 const / copy / 算术 / load / store / addr(frame)。
> `call` / `return` / `asm` 和条件形式留给后面；`addr(global)` 在 program-layout 解析。
> 选择表和 native 操作数顺序见 [`LOWER.md`](LOWER.md)。测试在 `test/lower-test.rkt`。

---

## Step 4.6：call / return lowering

输入：lower-ops 之后的 machine IR + frame。

设计：

- 参数全部走 caller 的 outgoing stack area；
- 返回值放 x10；
- x1 RA、x2 SP、x8 FP；
- 第一版无 callee-saved；
- call-lower 插 prologue，写参数，发 `(call-target (global f))`；
- return 插 epilogue，term 变 `(term (return))`；
- layout-relax 把 `(term (return))` 变成 `jalr`，`call-target` 先保留；
- program-layout 再把 `call-target` 变成近 `jal` 或远 `auipc+jalr`。

> 当前状态：`ir/call-plan.rkt` 和 `ir/call-lower.rkt` 已实现。
> 测试在 `test/call-plan-test.rkt`、`test/call-lower-test.rkt`。
> 完整约定见 [`CALL.md`](CALL.md)。

---

## Step 5：layout 物化边

输入：call-lower 之后的 machine IR。

输出：扁平 item 流：

```scheme
(label b0)
...
(bne ...)      ; layout 选择的条件分支
(label b1)
...
(label b2)
...
```

检查：

- `(term (jump b))` 如果 `b` 是下一块，不产生指令。
- `(term (jump b))` 如果 `b` 不是下一块，产生 `j` / `jal x0` / 远形式。
- `(term (branch cond b1 b2))` 根据物理顺序选择：
  - 正向条件分支；
  - 反向条件分支；
  - 条件分支 + 无条件跳转。
- `return` / `trap` 由 lower/ABI/平台层处理。
- 函数间 gap 只产生 padding，不产生跨函数 fallthrough。
- `j` / `b` 只在这一步之后存在。

验收例子：

- `examples/branch.rkt` 中 `b1` 的 `(jump b2)`，当 `b2` 紧随时被删掉。
- `b0` 的 `branch` 根据 `b1` / `b2` 的顺序选择 `beq` 或 `bne`。

> 当前状态：`layout/policy.rkt`、`layout/plan.rkt`、`layout/relax.rkt` 已实现。
> layout-relax 支持 direct branch/jump、inline far branch、far jump、call-target、
> return、trap，并迭代到固定点。
> 函数内 islands 已实现：只在非 fallthrough 边界 / 函数末尾放 island；
> 不拆块；无 slot 直接报错；不共享、不链；mixed island/inline policy 暂不支持。
> 测试在 `test/layout-relax-test.rkt`、`test/layout-islands-test.rkt`。
> 设计见 [`layout/README.md`](layout/README.md) 和 [`REVIEW.md`](REVIEW.md) 3.18。

---

## Step 5.5：program layout / call-target / data / addr(global)

输入：多个已 call-lower 的 machine func + `raw` 单元 + `data` 段。

输出：`program-layout`。

检查：

- 函数名 / raw 名 / raw label / data 名 / data label 唯一，共用一个全局名字空间；
- 每个函数先走 `layout-plan` + `layout-func`；
- 计算函数起始偏移；
- `call-target` 初始按 8 字节预留；
- 能放进 `jal` 的调用缩短为 4 字节；
- 远调用落成 `auipc x1, hi` + `jalr x1, x1, lo`；
- `addr(global)` 固定 8 字节，解析成 `auipc` + `addi`；
- data 的 `(label ...)` 进入全局地址表；
- data 的地址初值在所有段放置后按 `origin + 目标偏移 + addend` 回填；
- 函数在前，raw 单元按输入顺序在后，data 段最后；
- data 段按自己的最大 align 对齐；
- 尺寸只减不增，迭代到固定点；
- 目标必须在同一程序里；
- 不做外部符号 / relocation / linker。

> 当前状态：`layout/program.rkt` 已实现；`encode-program` 按 section 编码并拼接，
> raw 段、data 段字节和段间 padding 也会写出。
> 测试在 `test/layout-program-test.rkt`、`test/data-layout-test.rkt`、
> `test/raw-test.rkt`。data 形状见 [`DATA.md`](DATA.md)，raw 规则见
> [`RAW.md`](RAW.md)。

---

## Step 6：encode

输入：layout 后的扁平 item 流。

`encode` 只编码，不判断范围、不展开分支、不插 island。

检查：

- 用 `../riscv-asm` 编码。
- 每条指令的字节数和 layout 记录一致。
- 目标和当前地址的偏移正确。
- 远形式不越界。
- 没有 `($ x)` / `(native ...)` 的非法操作数。

验收：

- 对 `examples/minimal.rkt` 和 `examples/branch.rkt` 做逐字节对照。
- 先只测固定短跳；远形式单独加。

---

> 当前状态：`encode/encode.rkt` 已实现固定 32-bit native 指令、label 相对偏移、
> little-endian bytes、`call-jal`、data section，以及 `encode-program` 的 section
> 拼接和段间 padding。单函数 `layout-result` 里未解析的 `call-target` /
> `addr-global` 仍然显式报错。
> 测试在 `test/encode-test.rkt`、`test/layout-program-test.rkt`、
> `test/data-layout-test.rkt`。设计见 [`encode/README.md`](encode/README.md)。

---

## Step 7：可选层

这些不属于核心，等 Step 0–6 稳定后再加：

- `addr` 的地址展开；
- `call` / `return` 的 ABI lowering；
- frame base / slot 偏移；
- 远跳 / trampoline；
- 间接控制流；
- 更复杂的分配策略（linear-scan / call-aware）。

---

## Step 8：前端 module / 多文件 / asm

这一步可以独立实现；在流水线里位于 virtual IR 之前。它只影响输入，不改变 virtual IR 形状。

> 当前状态：`frontend/` 已实现 8.1 和 8.2 的名字解析，并用 `test/frontend-test.rkt`
> 覆盖。8.3 的 inline asm 已接入 allocation / materialize / layout / encode。

### 8.1 module 解析

输入：多个文件，每个文件包含顶层 `(module ...)` 或隐式根 form。

检查：

- 每个 module 只在一个文件里完整出现。
- `provide` / `require` 只引用全局名。
- `vregs` / block 名不能出现在 `provide` / `require` 里。
- 缺 module、重复 module、未导出名字在前端报错。
- 解析结果没有 `module`，只有完整链的 `func` / `data` / `raw`。

### 8.2 `raw`

检查：

- `raw` 是 machine 层，不经过 virtual IR / allocation。
- `raw` 的全局 label 受 module 可见性管理。
- `raw` 可以包含 `label` / `j` / `b`，这是纯汇编的明确例外。

> 当前状态：`raw/raw.rkt` 已实现封闭单元内 label / `j` / 条件分支 / `jal` /
> native 指令的规范化；program-layout 和 encode-program 已支持 raw section。
> 固定 4 字节，不做 raw 内远跳 relaxation；跨 raw 跳转显式报错。
> 测试在 `test/raw-test.rkt`。完整规则见 [`RAW.md`](RAW.md)。

### 8.3 `asm`

检查：

- `asm` 只出现在 block 里，是一个 op。
- `inputs` / `outputs` 都是 `((vreg) (native xN))`。
- `clobber` 是 `(native xN)` 列表。
- `code` 里没有 `($ ...)`；局部 label 只在 `code` 内。
- `code` 是 machine 层，允许 native 指令和局部 `label` / 分支。
- allocation 把 `asm` 当成一个 op：uses = inputs，defs = outputs，clobber = clobber。
- materialize 负责 input/output move，并把 code 规范化为 `(asm-code ...)`。
- `asm` 不跳到函数 block，不直接引用全局名。

> 当前状态：`ir/materialize.rkt`、`asm/code.rkt`、`layout/relax.rkt`、
> `encode/encode.rkt` 已实现。input/output 支持寄存器 / slot / parallel move；
> clobber 作为函数级不可用寄存器；code 内固定 4 字节，局部 label 封闭。
> 测试在 `test/materialize-test.rkt`、`test/asm-code-test.rkt`。
> 设计边界见 [`ASM.md`](ASM.md) 和 [`REVIEW.md`](REVIEW.md) 3.3。

### 8.4 回归

- 后端输入里没有 `module` / `provide` / `require`。
- 多文件解析后，同一个全局名只有一份定义。
- 纯汇编 module 和核心 module 使用同一个 module 形状。

---

## Step 9：统一 driver / 端到端

输入：source forms / files / resolved program。

输出：`compiled-program`：

```scheme
(compiled-program
  bytes
  layout
  encoded
  exports
  scratch-budget)
```

检查：

- `compile-source`：frontend -> pipeline -> layout -> encode
- `compile-files`：多文件
- `compile-resolved-program`：跳过 frontend
- scratch budget 从 0 开始，`scratch-exhausted` 后 +1 重跑
- 默认 runtime forbidden：`x1/x2/x8/x10/x11`
- 每个 func 独立跑 allocate / materialize / call-lower
- data / raw 最后和 machine func 一起 layout / encode

当前状态：已实现。实现见 [`driver/README.md`](driver/README.md) 和
[`driver/compile.rkt`](driver/compile.rkt)；测试在 `test/driver-test.rkt`。

仍缺：

- 外部符号 / relocation / linker；
- 任意 64-bit 全局地址；
- 精确的 per-stage scratch-request；
- source location / 诊断。

---

## Step 10：外部符号 / relocation / link

输入：

- build source
- interface source
- address data

流程：

```text
interface source
  -> extern 表
build source + extern 表
  -> frontend -> pipeline -> program-layout
  -> extern call / addr / data value 生成 relocation
  -> encode 输出 bytes + relocations
  -> link(address data) 回填
```

检查：

- interface source 不产生 unit
- extern 只有名字 + kind
- address data 只提供地址
- 本地名 / extern 名冲突报错
- external call 只能指向 func
- unresolved / 多余 address 报错
- 外部 call / addr 固定 8 字节形式
- data 外部地址初值保留 width

当前状态：已实现。实现见 [`link/README.md`](link/README.md)；
测试在 `test/frontend-test.rkt`、`test/external-test.rkt`。

仍缺：

- object / ELF
- section 重排 / GC
- linker relaxation / veneer
- 外部地址 far 形式
- 动态链接

---

## 每次改动后的回归

1. 跑 `verify-virtual`。
2. 分配相关改动跑 `analyze-liveness` + `allocate-func`，再用 `verify-allocation` 自检。
3. 跑 `verify-allocation`。
4. 跑 `verify-machine`（materialize / lower-ops / call-lower 之后）。
5. 检查没有 `j` / `b` 出现在 layout 之前。
6. 检查没有 `($ x)` 出现在 materialize 之后。
7. 检查没有 C ABI 名字进入核心 IR。
