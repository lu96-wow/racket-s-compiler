# layout

`layout` 是 middle-end 的独立布局阶段，不是 module frontend，也不是 encoder。

它把“顺序、边形式、island、scratch 需求”集中到一处；`encode` 只编码最终形式，
不再判断范围、不再展开分支。

## 位置

```text
virtual IR
  -> verify
  -> CFG
  -> layout-plan                 ; 现在已实现：block 顺序 / fallthrough
  -> allocate(scratch-budget)
  -> materialize
  -> call-plan
  -> frame-layout                ; 使用 outgoing-size
  -> lower-ops                   ; frame-slot / load/store / 算术
  -> call-lower                  ; prologue / call-target / return
  -> layout-relax                ; 函数内：direct + inline far；island 下一步
  -> flat items + call-target
  -> program-layout              ; 函数 + data 偏移；call-target / addr(global)
  -> encode                      ; 只编码
```

为什么最终 layout 不放在 allocation 之前：

- spill load/store 会改变尺寸；
- `const` / 大偏移 / `addr` 展开会改变尺寸；
- frame setup 会改变尺寸；
- 只有 materialize / frame-layout / lower-ops / call-lower 之后，偏移才准确；
- b/j 是否超范围又依赖偏移，所以 `layout-relax` 自身也要迭代到固定点。

block 顺序可以早定，但边形式不能早定。`layout-plan` 只做前者。

## 文件

| 文件 | 作用 |
| --- | --- |
| `policy.rkt` | 策略配置：order / far-branch / far-jump / scratch / rvc |
| `plan.rkt` | block 顺序、entry 放最前、fallthrough 选择 |
| `relax.rkt` | 已实现：函数内偏移、branch/jump/call-target/return、inline far、islands、固定点 |
| `program.rkt` | 已实现：多函数 + data 偏移、call-target 近/远解析、addr(global) 解析 |
| `size.rkt` | 以后：island / RVC 的尺寸模型 |
| `islands.rkt` | 以后：把 island 逻辑从 `relax.rkt` 拆出，并加共享 / 链 |
| `emit.rkt` | 以后：拆出独立 emitter |

## 默认策略

```scheme
(layout-policy
  (order text)              ; text | greedy | profile
  (far-branch inline)       ; inline | islands | indirect
  (far-jump inline)         ; inline | islands | indirect
  (scratch feedback)        ; feedback | conservative
  (rvc? #f))
```

当前实现：

- `order = text`：entry 放最前，其余保持 CFG 文本顺序；
- `far-branch` / `far-jump` 默认 inline；
- 两者都设为 `islands` 时启用函数内 island 模式；
- 混合 island/inline policy 显式报未实现；
- `rvc?` 打开会显式报未实现；
- 其它 order / indirect 策略显式报未实现。

## layout-plan

输入：`cfg`。

输出：

```scheme
(layout-plan
  (name (main))
  (entry b0)
  (order b0 b1 b2)
  (fallthrough (b0 b1) (b1 b2)))
```

规则：

- `entry` 一定在 `order` 最前；
- 其余 block 保持 CFG 文本顺序；
- `fallthrough` 只在“物理下一块正好是该 block 的后继”时成立；
- 不可达 block 保留在 `order` 里，DCE 是别的 pass；
- 不决定 b/j 形式、字节、island、scratch。

## layout-relax 当前实现

`layout/relax.rkt`：

- 按 `layout-plan` 顺序铺 label + native ops；
- `(term (jump b))`：下一块就不发；否则 `jal x0, b`；
- `(term (branch c b1 b2))`：
  - 下一块是 `b1`：发反向条件分支到 `b2`；
  - 下一块是 `b2`：发正向条件分支到 `b1`；
  - 都不是：条件分支 + 无条件跳转；
- 条件映射：`eq/ne/lt/le/ltu/leu` -> `beq/bne/blt/bge/bltu/bgeu`；
  - `le` / `leu` 交换操作数；
- 条件里的 0 用 `x0`；非 0 立即数用 scratch + `li`；
- `(call-target (global f))` 在函数内保持符号形式，按 8 字节计；
- `(addr (native xN) (global ...))` 保留成 `(addr-global ...)`，按 8 字节计；
- `(asm-code ...)` 是封闭块，按内部 4 字节指令计；局部 label 不进入函数 CFG；
- `(term (return))` -> `jalr x0, x1, 0`；
- `(term (trap))` -> `ebreak`；
- 远 branch：反向分支 + `jal` + skip label；
- 远 jump：`auipc scratch` + `jalr x0, scratch`；
- 迭代到固定点，远形式只增长。

当前 islands：

- 只在 `far-branch = far-jump = islands` 时启用；
- slot 只放在非 fallthrough 的 block 边界 / 函数末尾；
- 不拆基本块；
- 无可达 slot 直接报错；
- 一 edge 一 island，不共享；
- 不做 island 链；
- 成功的 island 形式零 scratch；条件立即数仍可能需要 scratch。

未实现：

- island 共享 / island 链；
- 混合 island/inline policy；
- RVC；
- 外部符号 relocation / linker。

## program-layout

`layout/program.rkt` 处理函数和 data 段之间的事：

- 输入是多个已 call-lower 的 machine func + `raw` + `data` + extern 表；
- 每个函数先走 `layout-plan` + `layout-func`；
- `call-target` 初始按 8 字节 `auipc+jalr` 预留；
- `addr(global)` 固定按 8 字节 `auipc+addi` 预留；
- 计算函数起始偏移；
- 能放进 `jal` 的调用缩成 4 字节 `call-jal`；
- 尺寸只减不增，迭代到固定点；
- 远调用落成 `auipc x1, hi` + `jalr x1, x1, lo`；
- `addr(global)` 近形式落成 `auipc dst, hi` + `addi dst, dst, lo`；
- 远形式落成绝对 `lui dst, hi` + `addi dst, dst, lo`，仍然 8 字节；
- data 的 `(label ...)` 进入全局地址表；
- data 地址初值在所有段放置后按 `origin + 目标偏移 + addend` 回填；
- 函数在前，raw 单元按输入顺序在后，data 段最后；
- raw 单元内部固定 4 字节；raw 名字 / label 进入全局地址表；
- data 段按自己的最大 align 对齐；段间补 0；
- 目标必须在同一个程序里，否则查 extern 表；
- 外部 call -> `(reloc-call ...)`，外部 addr -> `(reloc-addr ...)`；
- data 外部地址初值保留为 data external relocation；
- 外部符号地址由 `link/` 用 address data 回填；
- 函数名 / data 名共用一个全局名字空间，重复报错；
- 不做外部符号、重定位、linker。

输出：

```scheme
(program-layout
  (sections
    (function-section (name (main)) (base 0) (size 12) (items ...))
    (raw-section (name (start)) (base 12) (size 16) (items ...))
    (data-section (name (d table)) (base 32) (size 24) (align 8)))
  (size 40)
  (bases ((main) 0) ((d table) 16)))
```

`encode-program` 按 section 编码并拼接；code section 的 labels 是段内偏移，
data section 直接写 data 字节。

data 形状见 [`../DATA.md`](../DATA.md)，raw 规则见 [`../RAW.md`](../RAW.md)。

远条件分支优先：

```text
b<cond> island
...
island:
  jal x0, target
```

- island 只放在不会破坏 fallthrough 的 block 边界或函数末尾；
- **不拆基本块**，也不在基本块中间插 island；
- 基本块太大导致找不到可达 slot 时，直接报错；
- `far-*=islands` 不偷偷退回 inline / scratch；要 inline 就显式选 policy；
- island 的 `jal` 超范围时第一版报错，island 链以后再加；
- 这样函数内控制流可以做到 **layout 零 scratch**。

远无条件跳转的顺序：

```text
直接 jal -> island -> island chain（以后）-> indirect + scratch（后备）
```

## 策略 B：统一 scratch 预算

scratch 不只服务 layout，也可能服务：

- materialize 的 spill；
- call lowering；
- asm 的 input/output move；
- layout 的后备 indirect 跳转。

所以驱动采用统一的 `scratch-budget` 固定点：

```text
budget = 0
loop:
  allocation = allocate(func, budget)
  machine    = materialize(func, allocation)
  call-info  = call-plan(machine)
  framed     = frame-layout(func, allocation, call-info.outgoing-size)
  lowered    = lower-ops(machine, framed)
  calls      = call-lower(lowered, framed)
  layout     = layout-relax(calls, plan, budget)
  need       = max(all stages' scratch-request)
  if need <= budget: done
  budget = need
```

- budget 只增不减，保证终止；
- 各阶段预算不足时返回 `scratch-request`，不要自己抢寄存器；
- 寄存器全被 pin / reserve 占满时，由 allocation 报明确的约束错误；
- `(scratch (native xN) ...)` 已经支持多个 scratch；
  各阶段按需要取，不够时显式报错。

## backend 边界

`encode` 只接受已经选好形式的 flat items：

- label；
- native 指令；
- 已经选好的 `b` / `j` / `jal` / `jalr`；
- 数据字节。

`encode` 不做：

- 范围判断；
- 反向条件分支；
- island 插入；
- `auipc` + `jalr` 展开；
- block 重排；
- scratch 选择。
