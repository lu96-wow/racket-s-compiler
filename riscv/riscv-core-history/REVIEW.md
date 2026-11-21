# 设计审查与未定点

> 本文做两件事：
> 1. 固定 `riscv-core` 的全局边界，避免各层偷偷补语义。
> 2. 记录已经修掉的不一致，以及还没有决定的问题。
>
> **未定点不是“随便选一个”**。在解决前，相关层不得自己发明规则；
> 新代码如果碰到未定点，先在这里补决定，再实现。

---

## 1. 全局边界（当前定稿）

### 1.1 四层名字

| 层 | 形状 | 可见性 |
| --- | --- | --- |
| 全局名 | `(lib f)`、`(d table)` | module 的 `provide` / `require` |
| 函数局部 | vreg `($ x)`、block `b0` | 只在当前函数 |
| asm 局部 | inline asm 的 `loop` | 只在 `asm.code` 内 |
| 物理寄存器 | `(native xN)` | `alloc` 约束、`asm` 边界、machine IR |

规则：

- module 只管理全局名。
- `vregs` / block 名不能 `provide` / `require`。
- 跨模块变量是 `data` + `addr` / `load` / `store`，不是 vreg。
- 函数之间不共享 vreg；值通过参数/返回值传递。
- 物理寄存器不进普通 virtual op；`asm` 是显式例外。

### 1.2 三套代码形状

```text
virtual IR
  func / vregs / block / op / term / ($ x)
  asm 是特殊 op，边界是 inputs / outputs / clobber
        │
        ▼
allocation
  只产出 (vreg location) 映射 + scratch
        │
        ▼
materialize
  唯一允许同时看到 ($ x) 和 (native xN) 的层
        │
        ▼
machine IR
  native / frame-slot / 整数 / global
  block / term 形状不变
        │
        ▼
lower-ops
  load/store/算术 -> native，不新增 vreg
        │
        ▼
frame-layout
  slot -> frame 偏移
        │
        ▼
layout
  block 顺序、gap、fallthrough、j/b/far、addr 展开
        │
        ▼
flat machine items
  label + native 指令 + j / b / jal / jalr
        │
        ▼
encode
```

特殊路径：

```text
raw ──────────────────────────────→ layout / encode
```

`raw` 是纯汇编，本来就是 machine 层，不走 virtual IR / allocation / materialize。

### 1.3 硬边界

1. `module` 只在前端；后端输入没有 `module` / `provide` / `require`。
2. `j` / `b` / `label` 只出现在 layout 之后；`asm.code` / `raw` 是 machine 层例外。
3. 核心 IR 不含 C ABI：没有 `a0` / `ra` / `sp`、没有 prologue/epilogue。
4. 分配前只改 vreg / CFG / def-use；分配后才做位置相关改写。
5. `allocation` 是映射表，不是代码；条目是 `(vreg location)` 二元 proper list。
6. materialize 之后不能再出现 `($ x)`。
7. layout 是唯一决定 fallthrough / 跳转形式的地方。
8. `asm` / `raw` 是封闭的 machine 代码块，不进入外层函数 CFG。
9. 所有判断用 list 操作：`match` / `assoc` / `equal?`，不做字符串前缀解析。

---

## 2. 已修的不一致

| 位置 | 问题 | 当前决定 |
| --- | --- | --- |
| `MODULES.md` | `provide (data table)` 与 `data (table)` 对不上 | `provide` 只列全局名：`(f)`、`(table)`、`(start)` |
| `MODULES.md` | 源码例子直接写已解析的 `(global (lib f))` | 源码写 `(global (f))`；解析后才变 `(global (lib f))` |
| raw / inline asm 示例 | `bne` 目标写在最后，和 native 目标在前不一致 | 统一成目标在前：`(bne (loop) ...)` / `(bne loop ...)` |
| `SYNTAX.md` / `PHASES.md` | `(slot n)` 既当 location 又当 machine 值操作数 | allocation 用 `(slot n)`；machine 地址用 `(frame-slot n)` |
| `PHASES.md` / `PLAN.md` | 缺少 instruction selection 阶段 | 增加 `lower-ops`：`load`/`store`/算术 -> native |
| `PLAN.md` | `../../riscv-asm` 路径错误 | 改成 `../riscv-asm` |
| `PHASES.md` / `PLAN.md` / `README.md` | `asm` 的 native 元数据与“virtual IR 无 native”冲突 | 给 `asm` inputs/outputs/clobber/code 加显式例外 |
| `OPS.md` / `PHASES.md` | 有 `(address-taken)` 却没有取本地地址的 op | 增加 `(addr dst ($ x))`；该 vreg 必须分配 slot |
| `PHASES.md` / `PLAN.md` | `scratch` 的来源不清楚 | `(scratch (native xN) ...)` 是 allocation 的单独输出 |
| `SYNTAX.md` | `clobber` 写成“调用点”，形状却是函数级 | 改成“本函数内调用的保守并集” |
| `PHASES.md` | `prologue/epilogue` 与“核心不含 C ABI”冲突 | 改成可选的 `frame setup / teardown` |
| `MODULES.md` | `prefix-in` 用 `p:`，是字符串式前缀 | 改成链头 `(prefix-in p ...)`，得到 `(p f)` |
| `MODULES.md` | `rename-in` / `rename-out` 的 bullet 形状不精确 | 统一成 `((本地链 外部链) ...)` / `((外部链 本地链) ...)` |
| `CONTROL.md` | branch 示例把正向/反向条件说反了 | 按“第二个后继是物理下一块”重写 |
| `SYNTAX.md` | `data` 只有名字，没有 body 形状 | 标为未定；当前只固定名字和可见性 |

---

## 3. 未定点

以下问题**还没有最终决定**。在解决前，不要把它们写死进实现。

### 3.1 `data` body 形状（已定）

| 问题 | 决定 |
| --- | --- |
| data 形状 | `(data chain item ...)` |
| item | `(align n)` / `(bytes b ...)` / `(fill n b)` / `(value w v)` |
| `align` | 正的 2 的幂；补 0 |
| `bytes` | 每个 b 在 `0..255` |
| `fill` | `n` 非负，b 在 `0..255` |
| `value` | w ∈ {1,2,4,8}；整数按补码低 `8w` 位写；little-endian |
| 地址初值 | `(global chain)` / `(+ (global chain) n)`；w ∈ {4,8} |
| 地址回填 | program-layout：`origin + 目标偏移 + addend`；默认 origin 0 |
| data 内部 label | `(label chain ...)`；全局名，偏移为当前段内偏移 |
| `reserve` / hole | v1 不支持 |
| 全局名字空间 | func / data 共用一个；重复报错 |
| 段顺序 | func 在前，data 按输入顺序在后 |
| 段对齐 | 段起点对齐到该段内最大 `align` |
| 地址操作 | `(addr dst (global chain))`；不支持 `(+ (global ...) n)` |
| 地址解析 | program-layout：近用 `auipc` + `addi`；远用绝对 `lui` + `addi`；都固定 8 字节 |
| 远地址限制 | 绝对地址必须能由 `lui+addi` 表示；否则报错 |

实现：[`data/data.rkt`](data/data.rkt)、[`layout/program.rkt`](layout/program.rkt)、
[`encode/encode.rkt`](encode/encode.rkt)；测试：`test/data-test.rkt`、
`test/data-layout-test.rkt`。完整设计见 [`DATA.md`](DATA.md)。

仍开放的点：

- `(reserve n)` / hole 段；
- 地址减法 / 符号相减；
- raw 与 data 的统一布局；
- 带 scratch 的任意 64-bit 全局地址；
- 外部符号 / relocation。

### 3.2 `raw` 与 layout / encode 的接口（已定）

| 问题 | 决定 |
| --- | --- |
| raw 形状 | `(raw chain item ...)`；chain 是入口全局 label |
| item | `(label chain ...)` / `(j chain)` / 条件分支 / `(jal (native xN) chain)` / native 指令 |
| label | raw 名字在 0；内部 label 是全局名，可 provide |
| 控制目标 | 必须在同一个 raw 单元内 |
| 尺寸 | 非 label item 固定 4 字节；不展开 pseudo / 远跳 |
| 放置 | func 先，raw 按输入顺序，data 最后 |
| 地址 | raw 名字 / label 进入 program 全局地址表；可被 addr / data 地址值引用 |
| 调用 | raw 不是 call-target 目标 |
| encode | raw section 内解析 label；跨 section 目标不支持 |
| 前向兼容 | raw 内 relaxation / island / 跨 unit 跳转以后再加 |

实现：[`raw/raw.rkt`](raw/raw.rkt)、[`layout/program.rkt`](layout/program.rkt)、
[`encode/encode.rkt`](encode/encode.rkt)；测试：`test/raw-test.rkt`。
完整规则见 [`RAW.md`](RAW.md)。

仍开放的点：

- raw 内远跳 / island；
- 跨 raw / func 的跳转；
- raw 内 pseudo 自动展开；
- raw 与 data 共用一个 section；
- external relocation。

### 3.3 `asm` 的 materialize 细节（已定）

| 问题 | 决定 |
| --- | --- |
| input move 消除 | vreg 已在目标物理寄存器则省略 |
| input 在 slot | 直接 load 到目标寄存器 |
| output move 消除 | vreg 位置就是目标寄存器则省略 |
| output 在 slot | 直接 store |
| 物理寄存器 move | parallel move 排序；环用 scratch 打断 |
| scratch | 不能与 move 源/目标重叠；不足报错 |
| input 目标重复 | 两个不同 vreg 绑同一目标寄存器 -> 报错 |
| output 目标重复 | 两个不同 vreg 绑同一目标寄存器 -> 报错 |
| input/output 共用 vreg | 必须绑定同一个物理寄存器 |
| clobber 与 input/output 重叠 | v1 报错 |
| clobber 与 allocation | asm clobber 并集作为函数级不可用寄存器 |
| code 形状 | materialize 规范化为 `(asm-code ...)`，封闭块 |
| code 内分支 | 只允许 code 内局部 label；固定 4 字节，不做远跳 relaxation |
| barrier | v1 视为封闭块，不跨它调度 |

实现：[`ir/materialize.rkt`](ir/materialize.rkt)、[`asm/code.rkt`](asm/code.rkt)、
[`layout/relax.rkt`](layout/relax.rkt)、[`encode/encode.rkt`](encode/encode.rkt)；
测试：`test/materialize-test.rkt`、`test/asm-code-test.rkt`。

仍开放的点：

- code 内远跳 / island；
- 显式 memory / scheduling barrier 标记；
- clobber 与 input/output 重叠的安全形式；
- asm 的寄存器约束 class（early-clobber / tied operand）；
- 跨 asm 的优化限制。

### 3.4 module 解析的边角规则（前端第一版已定）

| 问题 | 决定 |
| --- | --- |
| 嵌套 module 是否支持 | 第一版不支持，直接报错；以后可作为前端 sugar 加 |
| 重复 `provide` 同一个名字 | 指向同一个完整名则幂等；指向不同完整名报错 |
| `prefix-in` / `rename-in` 产生同名冲突 | 由 import 冲突检查报错（同一个 local 不能指向两个完整名），也与本模块定义冲突 |
| `provide *` 是否包含 `raw` 内部的 label | 包含；`raw` label 是模块作用域的全局名 |
| 一个 module 跨多个文件是否允许 | 不允许；同一 module 名第二次出现即报错 |
| 循环 `require` 是否允许 | 允许；只做名字解析，没有初始化顺序。没有 base 的环在收敛后报未定义/未导出 |
| `provide` 是否可以 re-export 导入名 | 允许 |
| `rename-in` 是过滤还是覆盖 | 导入目标全部导出，只改列出的外部名 |
| `rename-in` / `rename-out` 形状 | 都只收一个 pair 列表：`((外部链 本地链) ...)` / `((本地链 外部链) ...)` |

实现与测试见 [`frontend/README.md`](frontend/README.md) 和 `test/frontend-test.rkt`。

仍然开放的点：嵌套 module 的链组合、`provide *` 是否应该排除 raw 内部 label、
以及 `raw` 中 `la` 等地址操作数何时进入名字解析。

### 3.5 frame / slot 的落地址

问题：

- `(slot n)` 的 size / align 从哪来？只从 vreg 类型，还是 slot 自己声明？
- `(frame-slot n)` 怎么变成具体基址 + 偏移？
- frame 基址由平台、ABI 还是 layout 决定？
- `(frame (size n))` 是分配结果还是布局结果？
- 多个函数/`raw` 的 frame 如何隔离？

当前约束：

- `(slot n)` 是 allocation location。
- `(frame-slot n)` 是 machine 地址。
- 具体基址和偏移不是 C ABI，由 frame-layout / 平台层决定。

### 3.6 `call` 无返回值

问题：

- 没有返回值时，`(call dst ...)` 的 `dst` 写什么？
- 用 `($ _)` 占位，还是允许 `()` / `#f`？
- 占位 vreg 是否参与 liveness / allocation？

当前约束：

- `call` 是普通 op，不是 term。
- 返回值目标显式写出。
- 参数按顺序显式写出。

### 3.7 `lower-ops` 的完整选择表

问题：

- `load` / `store` 的宽高、符号、offset 范围如何选择具体助记符？
- `add` 的立即数什么时候用 `addi`，什么时候 `li` + `add`？
- `const` 的 `li` 序列什么时候在 allocate 前展开，什么时候在 `lower-ops` 做？
- `addr` 的 `auipc` + `addi` / 绝对序列怎么选？
- 远形式由 `lower-ops` 还是 `layout` 决定？

当前约束：

- 引入新 vreg 的 lowering 在 allocate 前。
- 只改物理形式的 lowering 在 `lower-ops`。
- 依赖最终地址的 `addr` / 远形式在 `layout`。
- `lower-ops` 不新增 vreg。

### 3.8 本地 `addr` / address-taken

问题：

- `(addr dst ($ x))` 在 materialize 后变成什么？
- 是 `(addr dst (frame-slot n))`，还是直接一条 native `add`？
- `(address-taken)` vreg 的 spill/reload 和普通 spill 是否共用 slot 分配？
- 取地址后，vreg 的值和它内存里的值如何保持一致？

当前约束：

- `(address-taken)` 的 vreg 必须分配 `(slot n)`。
- `addr` 的源可以是 `(global chain)` 或 `(address-taken)` vreg。
- materialize 把它变成 frame 地址。

### 3.9 virtual IR / allocation 验证约定（已定）

以下约定由 `ir/verify.rkt` 和 `ir/allocation.rkt` 实现，测试在
`test/verify-test.rkt`、`test/cfg-test.rkt`、`test/allocation-test.rkt`。
生成表的分配器见 3.16。

| 问题 | 决定 |
| --- | --- |
| `vregs` 是否必须写 | 必须；可以写成 `(vregs)` |
| 普通 op 的 `(global chain)` 操作数 | 允许；condition 里不允许，先 `addr` 进 vreg |
| `(native ...)` 的合法名字 | 只允许 `x0..x31`；`a0` / `ra` / `sp` 等 ABI 别名直接拒绝 |
| `asm` 条款 | `inputs` / `outputs` / `clobber` / `code` 四个都必须在，顺序不限 |
| `asm.code` | 封闭 machine 块；禁止 `($ ...)` / `(global ...)` / `(term ...)` |
| `address-taken` + `pin` | 冲突，verify 直接报错 |
| 同一 vreg 多次 `pin` | 同一寄存器幂等；不同寄存器报错 |
| allocation 缺项 | 代码里出现过的 vreg 必须有条目；未使用的已声明 vreg 可以没有 |
| allocation 多项 | 已声明但未使用的 vreg 可以有条目；未声明 vreg 不可以 |
| `address-taken` 的 location | 必须是 `(slot n)`，不能是 `(native xN)` |
| `pin` 与 allocation | 如果分配了，必须落在指定物理寄存器 |
| `reserve` 与 allocation | 普通 vreg 不能落进保留寄存器；显式 pin 到该寄存器除外 |
| `scratch` | 单独输出，不是 allocation 条目；可以写多个 `(native xN)`；同一个寄存器不能重复 |

实现文档：[`ir/README.md`](ir/README.md)。

### 3.10 layout / scratch 策略（已定）

| 问题 | 决定 |
| --- | --- |
| layout 放在哪里 | middle-end 独立阶段，在 allocation / materialize / lower-ops / frame-layout 之后，encode 之前；不放 module frontend |
| backend 是否展开 | 不展开；`encode` 只编码最终 flat items |
| block 顺序 | `layout-plan` 早定；第一版 text order，entry 放最前 |
| b/j 形式 | `layout-relax` 在尺寸稳定后决定；自身迭代到固定点 |
| 远条件分支首选 | 目标 island；已实现，但只放在非 fallthrough 边界 / 函数末尾 |
| 远无条件跳转首选 | 目标 `jal` -> island；已实现；island chain 以后再加 |
| 反向分支 + `jal` | 作为 inline 备选，不是唯一策略 |
| scratch | 统一 scratch-budget 协商；budget 只增不减，不足则重跑 allocation..layout |
| layout 自身 scratch | inline far jump / 非零条件立即数需要 scratch；island 形式本身零 scratch |
| RVC | 第一版关闭；policy 留 `rvc?` 开关 |
| scratch 形状 | `(scratch (native xN) ...)`，0 个或多个；同一个寄存器不能重复；共享实现在 `ir/scratch.rkt` |

实现文档：[`layout/README.md`](layout/README.md)。当前 `layout/relax.rkt` 已实现
direct branch/jump、inline far branch、far jump、函数内 islands、call-target、
return、trap；测试在 `test/layout-relax-test.rkt`、`test/layout-islands-test.rkt`。

仍开放的点：

- island 共享 / island chain；
- target 的 xlen / extensions / RVC 何时固定；
- 外部符号 / linker 的 relocation；
- RVC 的 2/4 字节选择。

### 3.11 内存 / 栈模型（已定）

| 问题 | 决定 |
| --- | --- |
| 第一版变量放哪 | stack-first：可变/可寻址变量住栈，表达式临时值住 vreg |
| 目标架构 | hybrid：以后把不逃逸、不取地址的变量提升到 vreg |
| 取局部变量地址 | 必须显式写 `(addr dst ($ x))`；没有隐式 local load/store |
| `(address-taken)` | 必须有稳定内存位置；allocation 强制 `(slot n)` |
| 栈的角色 | LIFO region；不是特殊 GC |
| 堆的角色 | precise、non-moving GC；捕获/逃逸对象进堆 |
| GC roots | 栈帧、寄存器、全局；stack map 按 safepoint 描述 |
| 栈帧 | 向下增长、16 字节对齐；SP/FP；header 默认 saved RA + old FP |
| slot offset | FP 到 slot 低地址的距离；地址 = `FP - offset` |
| 多个 vreg 共享 slot | 允许；frame-layout 取最大 size/align |
| 内部调用约定 | 不遵循 C ABI；参数全走 outgoing stack area，返回值 x10，第一版无 callee-saved；见 3.13 |
| xlen | `frame-layout` 参数，默认 64；以后固定 target |
| RVC | 第一版关闭 |

实现文档：[`MEMORY.md`](MEMORY.md)。frame-layout 已实现：
[`ir/frame.rkt`](ir/frame.rkt)，测试 [`test/frame-test.rkt`](test/frame-test.rkt)。

materialize 第一版已实现（[`ir/materialize.rkt`](ir/materialize.rkt)）：
寄存器 / slot / addr / branch / load / store、call slot 参数、call slot 返回值、
return slot 操作数，输出没有 `($ x)`。inline `asm` 暂时显式报错。
call-lower 选择 scratch 时会避开 call 参数寄存器，避免覆盖 materialize 预加载的值。

仍开放的点：

- `call/cc`、尾调用、异常、多返回值、varargs；
- moving GC 何时引入；
- stack map 的具体编码/查找；
- leaf function 是否省略 saved RA；
- slot sharing 的 liveness 检查放在哪个 pass；
- xlen 最终固定为 32 还是 64。

### 3.12 lower-ops 选择表（已定）

| 问题 | 决定 |
| --- | --- |
| lower-ops 做什么 | const / copy / 二元算术 / load / store / addr(frame-slot) |
| 是否新增 vreg | 不；只做指令选择 |
| native 操作数 | 继续写 `(native xN)` |
| load 顺序 | `(mnemonic rd rs1 imm)` |
| store 顺序 | `(mnemonic imm rs1 rs2)` |
| const/copy | `li` 展开；copy reg 用 `addi dst src 0` |
| 二元立即数 | s12 用 immediate 形式；shift 用 0..XLEN-1 |
| 大立即数 | scratch + `li` + 寄存器形式 |
| load/store 类型 | b8->lbu, s8->lb, b16->lhu, s16->lh, b32->lwu/lw, s32->lw, b64->ld/sd(RV64), ptr->ld/lw |
| frame-slot | `FP - offset`；超出 s12 用 scratch / li |
| `addr(global ...)` | 先原样保留，等地址模型 / layout |
| call / return / asm | 先原样保留或显式报错 |
| 条件形式 | 留给 layout 映射到 b 指令 |
| scratch | 一个 op 最多 2 个；不足显式报错 |

实现文档：[`LOWER.md`](LOWER.md)。实现：[`ir/lower.rkt`](ir/lower.rkt)，
测试：[`test/lower-test.rkt`](test/lower-test.rkt)。

仍开放的点：

- inline `asm` 的 materialize / lower；
- `addr(global ...)` 的地址模型；
- 条件到 b 指令的映射和求反；
- RV32 的 b64 load/store；
- RVC。

### 3.13 call / return lowering（已定）

| 问题 | 决定 |
| --- | --- |
| 参数 | 全部走 caller 的 outgoing stack area |
| 参数大小 | 每个参数一个 XLEN slot |
| 返回值 | 第一版 0/1 个，放 x10 |
| return address | x1 |
| SP / FP | x2 / x8 |
| callee-saved | 第一版没有；除 x1/x2/x8 外全部 caller-saved |
| 谁清理参数 | 不清理；outgoing area 在 caller frame 固定预留 |
| prologue | scratch 保存 old FP；FP = caller SP；减 frame；保存 RA/FP |
| epilogue | 恢复 RA/old FP；SP = FP；term 变 `(term (return))` |
| call 形式 | 参数写 outgoing area 后发 `(call-target (global f))` |
| layout 责任 | `call-target` -> `jal` 或 `auipc+jalr`；`(term (return))` -> `jalr x0, x1, 0` |
| 多返回值 | 暂不支持 >1 |
| tail call | 暂不支持 |
| indirect call | 暂不支持 |
| stack map | call site 标记 live pointer slots + outgoing pointer args |

实现文档：[`CALL.md`](CALL.md)。实现：[`ir/call-plan.rkt`](ir/call-plan.rkt)、
[`ir/call-lower.rkt`](ir/call-lower.rkt)；测试：`test/call-plan-test.rkt`、
`test/call-lower-test.rkt`。

仍开放的点：

- 多返回值用 x10/x11 还是 caller-provided return area；
- tail call 的 frame reuse；
- call/cc 的栈复制 / heap frame；
- callee-saved 集合何时引入；
- stack map 的二进制编码；
- 参数寄存器化；
- indirect call 的 IR 形状。

### 3.14 encode v1（已定）

| 问题 | 决定 |
| --- | --- |
| 单函数输入 | `layout-result` |
| 程序级输入 | `program-layout` |
| 单函数输出 | `(encoded bytes labels)` |
| 程序级输出 | `(encoded-program bytes sections)`；section labels 是段内偏移 |
| 字节序 | little-endian |
| 指令宽度 | 固定 32-bit；layout 假设 4 字节 |
| label | branch/jal 目标变成相对当前指令的偏移 |
| 寄存器 | `(native xN)` -> `xN`，交给 riscv-asm 适配层 |
| 全局操作数 | 需要外部 relocation，报错 |
| `call-target` | 单函数里显式报错；program-layout 已经解析成 `call-jal` / `auipc+jalr` |
| RVC | 关闭 |
| 多函数 / 多段 | 已支持多个 func + data；raw 还没有 |

实现：[`encode/encode.rkt`](encode/encode.rkt)，测试：[`test/encode-test.rkt`](test/encode-test.rkt)、
`test/layout-program-test.rkt`。指令编码复用 `riscv-compiler/encode/insn.rkt` 的
riscv-asm 适配层。

仍开放的点：

- object / ELF / full linker；
- raw 的最终布局；
- island chain / RVC 下的 island；
- RVC / 压缩指令；
- 带 scratch 的任意 64-bit 全局地址。

### 3.15 machine IR 验证（已定）

| 问题 | 决定 |
| --- | --- |
| 验证入口 | `verify-machine` / `verify-machine-program` / `verify-machine-func` |
| 输入 | materialize 之后的 func；可带或不带 frame |
| vreg | 完全不允许出现 `($ x)` |
| 值操作数 | `(native xN)`、整数、`(global chain)`；内存地址可以用 `(frame-slot n)` |
| `(slot n)` | 只在 frame 的 `slots` 条目里；不能当值操作数 |
| frame-slot | 有 frame 时，每个 `(frame-slot n)` 必须能在 frame 里找到 |
| scratch | 形状合法，且不能有重复寄存器 |
| term | `jump` / `branch` / `return` / `trap`；return 可以暂时带 machine 操作数，call-lower 后变 `(return)` |
| layout 形状 | `label` / `j` / `jal` / `jalr` / 条件分支指令不在 machine func 的 op 里；`asm.code` / `raw` 例外 |
| call-target | 只允许 `(call-target (global chain))` |
| inline asm | 如果出现在 machine IR，bindings 必须已经物化成 `(native xN)` |

实现：[`ir/verify-machine.rkt`](ir/verify-machine.rkt)，测试：
`test/verify-machine-test.rkt`。

仍开放的点：

- 是否要把 `asm.code` 的局部 label / 分支也纳入统一验证；
- `raw` 的 machine 验证何时接入；
- 是否要按阶段拆成 `verify-materialized` / `verify-lowered` / `verify-call-lowered`。

### 3.16 liveness 与分配生成（已定）

| 问题 | 决定 |
| --- | --- |
| liveness 入口 | `analyze-liveness`；返回 block live-in/out 和每条指令的 live-before/after |
| block use | upward-exposed use：第一次定义之前的 use |
| block def | block 内所有 def 的并集 |
| 数据流方程 | `live-in = use ∪ (live-out - def)` |
| asm | uses = `inputs`，defs = `outputs` |
| 干涉图 | 指令边界上同时 live 的值两两建边；不依赖“每个 vreg 都有定义” |
| 分配入口 | `allocate-func`，返回 `(values allocation scratch)` |
| 分配顺序 | 度降序、声明顺序升序 |
| address-taken | 必须落 `(slot n)` |
| pin | 先固定；互相干涉的两个 pin 不能同寄存器；不能 pin x0 |
| reserve / clobber | 普通 vreg 和 scratch 都避开 |
| forbidden | `#:forbidden` 用于 runtime contract；普通 vreg 和 scratch 都避开 |
| x0 | 永远不分配 |
| scratch | 先从可用寄存器预留，普通 vreg 不能占用 |
| spill | 没有可用颜色就分配唯一 slot |
| 自检 | 输出前跑 `verify-allocation` |
| 当前不做 | coalescing、slot sharing、调用点感知 liveness、scratch budget 自动反馈 |

实现：[`ir/liveness.rkt`](ir/liveness.rkt)、[`ir/allocate.rkt`](ir/allocate.rkt)；
测试：`test/liveness-test.rkt`、`test/allocate-test.rkt`。

仍开放的点：

- coalescing / move elimination；
- 非干涉 spill slot sharing；
- scratch budget 的自动反馈驱动；
- spill 代价模型；
- 调用点感知的 clobber liveness；
- RV32 下的分配与 spill；
- 分配结果是否要做确定性排序以外的稳定化。

### 3.17 program layout / 内部 call relocation（已定）

| 问题 | 决定 |
| --- | --- |
| 入口 | `layout-program`；输入是多个已 call-lower 的 machine func |
| 函数顺序 | 输入顺序；不做跨函数重排 |
| 函数名 | 必须唯一；重复报错 |
| call-target 初值 | 函数内先按 8 字节 `auipc+jalr` 预留 |
| 近调用 | 目标在当前指令 ±1MiB 内 -> `(call-jal delta)`，4 字节 |
| 远调用 | 否则 `auipc x1, hi` + `jalr x1, x1, lo`，8 字节 |
| 尺寸固定点 | call 从远缩短为近；尺寸只减不增，迭代到没有新近调用 |
| 目标解析 | 目标函数必须在同一程序里；未定义报错 |
| 外部符号 | program-layout 生成 placeholder + relocation；由 `link/` 用 address data 回填 |
| 函数间 padding | 当前所有 item 4/8 字节，不需要额外 padding |
| 输出 | `program-layout`：sections / base / size / bases / scratch-request |
| 编码 | `encode-program` 按 section 编码并拼接 |

实现：[`layout/program.rkt`](layout/program.rkt)、[`encode/encode.rkt`](encode/encode.rkt)；
测试：`test/layout-program-test.rkt`。

仍开放的点：

- 动态链接 / object 格式；
- raw 与 func / data 的统一布局；
- 函数对齐 / padding 策略；
- islands 与 program-level 交互；
- 跨 section 的 far call 后备；
- section GC / linker relaxation。

### 3.18 islands 设计边界（已定，已实现）

| 问题 | 决定 |
| --- | --- |
| 作用域 | 只在单个函数内；不处理 raw / asm-code / 跨函数 |
| island 形式 | 小跳板 `jal x0, target`；远条件分支先跳到 island |
| slot 位置 | 函数末尾，或不会破坏 fallthrough 的 block 边界 |
| 基本块 | **不拆块**，不在基本块中间插 island |
| 大块无 slot | 直接报错，要求用户自己拆块或改用 `inline` |
| 条件分支 | island 必须在 ±4KiB 内可达，否则报错 |
| 无条件跳转 | island 必须在 ±1MiB 内可达，否则报错 |
| 隐式回退 | `far-*=islands` 时不得偷偷退回 inline / scratch |
| scratch | 成功的 island 形式零 scratch |
| 共享 | 第一版可以一 edge 一 island；共享以后再加 |
| 链 | 第一版不自动生成 island 链；超范围报错 |
| 错误信息 | 必须指出 source block / target / 所需范围 / policy |
| encode | 仍然只编码最终 flat items |

设计原则：

> 布局层不替用户修 CFG。基本块太大导致 island 放不下，是输入程序的问题，
> 不是 layout 自动拆块的理由。

实现：`layout/relax.rkt` 内的 island 模式（未单独拆出 `layout/islands.rkt`），
测试：`test/layout-islands-test.rkt`。

第一版：

- 只有 `far-branch = far-jump = islands` 才走 island 模式；
- 一 edge 一 island，不共享；
- 不生成 island 链；
- 无可达 slot 直接报错；
- 成功的 island 形式 scratch request 为 0（条件立即数仍可能需要 scratch）。

仍开放的点：

- 同 target / 同 slot region 的 island 共享；
- island 链；
- 混合 island/inline policy；
- 显式 `island-fallback` policy（只有用户显式选择才 inline）；
- RVC 下的 2/4 字节 slot 模型；
- 把 island 逻辑拆成独立 `layout/islands.rkt`。

### 3.19 统一 driver / scratch budget 反馈（已定，已实现）

| 问题 | 决定 |
| --- | --- |
| 入口 | `compile-source` / `compile-files` / `compile-resolved-program` |
| 输出 | `compiled-program`：bytes / layout / encoded / exports / scratch-budget |
| scratch 不足 | `ir/scratch.rkt` 的 `scratch-exhausted` 专用异常 |
| 反馈策略 | budget 从 0 开始，捕获 `scratch-exhausted` 后 +1 重跑整个 program |
| 上限 | `#:max-scratch`，默认 31；超过后重新抛出 |
| runtime 固定寄存器 | 默认 `x1/x2/x8/x10/x11`，分配和 scratch 都避开 |
| func 流水线 | allocate -> materialize -> call-plan -> frame -> lower -> call-lower -> verify |
| data / raw | 不经过函数流水线，最后和 machine func 一起进 program-layout |
| 端到端测试 | 单函数、内部调用、func+raw+data、多文件 |

实现：[`driver/compile.rkt`](driver/compile.rkt)、[`driver/README.md`](driver/README.md)；
测试：`test/driver-test.rkt`。

仍开放的点：

- 只捕获 `scratch-exhausted`，没有各阶段返回的精确 `scratch-request`；
- budget 增加会重跑整个 program，没有增量缓存；
- 只有最小 link，没有 object/ELF / relaxation / veneer；
- 没有 source location / 诊断快照。

### 3.20 外部符号 / address data / 最小 link（已定，已实现）

| 问题 | 决定 |
| --- | --- |
| 外部源码 | interface source：只解析 module / provide / require / 定义名 + kind，不产生 unit |
| extern 形状 | `(extern chain (kind kind))` |
| kind | `func` / `data` / `raw` / `raw-label` / `data-label` |
| address data | `(address chain value)`；只在 link 使用 |
| kind 来源 | 只来自 interface source；address data 不重复提供 kind |
| 本地/外部冲突 | 同名全局定义报错；extern 也不能和本地名字冲突 |
| 外部 call | 只能指向 `kind func`；固定 8 字节 `auipc+jalr` + `call-pcrel` relocation |
| 外部 addr | 固定 8 字节 `auipc+addi` + `addr-pcrel` relocation |
| data 外部地址初值 | width 4/8，占位 0 + `abs` relocation |
| address data 校验 | 非 extern 符号、重复地址、unresolved 都报错 |
| link 范围 | 最小回填；不做 object/ELF、section 重排、relaxation/veneer |
| 外部 far | 超出 `auipc+jalr` / `auipc+addi` 报错 |

实现：[`frontend/main.rkt`](frontend/main.rkt)、[`link/external.rkt`](link/external.rkt)、
[`link/reloc.rkt`](link/reloc.rkt)、[`link/link.rkt`](link/link.rkt)、
[`encode/encode.rkt`](encode/encode.rkt)、[`driver/compile.rkt`](driver/compile.rkt)。
设计文档：[`link/README.md`](link/README.md)。测试：`test/frontend-test.rkt`、
`test/external-test.rkt`。

仍开放的点：

- object / ELF 格式；
- section 重排 / section GC；
- linker relaxation / far veneer；
- 外部地址的任意 64-bit far 形式；
- 动态链接 / GOT / PLT；
- 入口点 / 初始化 / runtime start。

---

## 4. 建议的决策顺序

先定会影响多个层的，再定局部细节：

1. **`data` body 形状**：影响 module、addr、layout、encode。
2. **`lower-ops` 选择表**：影响 machine IR 到 layout 的接口。
3. **frame / slot 落地址**：影响 spill、asm、addr、layout。
4. **`asm` materialize 细节**：影响 allocation 和 inline asm。
5. **`raw` 与 layout 接口**：影响纯汇编路径。
6. **`call` 无返回值**：局部约定，最后定。

已完成：

- module 边角规则：见 3.4；
- virtual IR / allocation 验证：见 3.9；
- liveness 与分配生成：见 3.16，已实现；
- layout / scratch 策略：见 3.10；
- 内存 / 栈模型和 frame-layout：见 3.11；
- materialize 第一版：见 3.11 末尾；
- lower-ops 选择表：见 3.12；
- call / return lowering 设计：见 3.13，已实现；
- encode v1：见 3.14，已实现；
- machine IR 验证：见 3.15，已实现；
- program layout / 内部 call relocation：见 3.17，已实现；
- data body / data 布局 / `addr(global)` / data 地址初值：见 3.1，已实现；
- raw 纯汇编单元 / layout / encode：见 3.2，已实现；
- inline `asm` materialize / layout / encode：见 3.3，已实现；
- 函数内 islands：见 3.18，已实现；
- 统一 driver / scratch budget 反馈 / source -> bytes：见 3.19，已实现；
- 外部符号 / address data / 最小 link：见 3.20，已实现。

下一步：object/ELF / linker relaxation、任意 64-bit 全局地址、
island 共享 / 链、运行时契约、RVC。
分配侧的后续：coalescing、slot sharing、scratch budget 自动反馈。

---

## 5. 每次改设计的全局检查

1. 这个名字属于哪一层？全局 / 函数局部 / asm 局部 / 物理寄存器。
2. 这个 pass 依赖 location 吗？依赖就放在 allocation 之后。
3. 这个 pass 会新增 vreg 或改 CFG 吗？会就放在 allocation 之前。
4. 它需要地址吗？需要就放在 layout 或 layout 之后。
5. 它会不会把 `j` / `b` 带进核心 IR？除了 `asm.code` / `raw`，不允许。
6. 它会不会引入 C ABI 名字或约定？不允许。
7. 它新增的 s-exp 形状是否仍然能用 `match` / `assoc` 判断？
8. 它和 `REVIEW.md` 的未定点冲突吗？冲突就先把决定写进这里。
