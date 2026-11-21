# 阶段边界

本文固定三件事：

1. 虚拟 IR 和 machine IR 是两套代码形状，不能混。
2. allocation 是一张映射表，不是代码；它只在分配后出现。
3. materialization 是唯一的桥。

已修冲突和未定点见 [`REVIEW.md`](REVIEW.md)。

> 当前实现：前端在 [`frontend/`](frontend/README.md)；virtual IR 形状、验证、CFG、
> liveness、分配生成（干涉图着色 + spill）、allocation 验证、materialize、call-plan、
> frame-layout、lower-ops、call-lower、machine IR 验证在 [`ir/`](ir/README.md)；
> 布局策略、layout-plan、layout-relax、program-layout 在
> [`layout/`](layout/README.md)。layout-relax 当前实现 direct + inline far；
> program-layout 已实现函数偏移、内部 call-target 近/远解析、data 段放置、
> data label、`addr(global)` 解析和 data 地址初值回填；encode 已实现固定 32-bit native
> 指令、data 字节和程序级拼接。
> raw 纯汇编单元、inline asm materialize / layout / encode、函数内 islands、
> 统一 driver / scratch budget 反馈 / source -> bytes、interface source / extern /
> relocation / address data / 最小 link 已接入；
> object/ELF、linker relaxation、island 共享 / 链、混合 island/inline policy、RVC 还没有实现。
> materialize 支持寄存器 / slot / addr / call slot 参数 / call slot 返回值 / return slot；
> inline asm 生成 `(asm-code ...)` 封闭块；
> lower-ops 支持 const/copy/算术/load/store/addr frame；scratch 形状 / 去重 / pool
> 在 [`ir/scratch.rkt`](ir/scratch.rkt)。
> 内存模型见 [`MEMORY.md`](MEMORY.md)，lower-ops 选择表见 [`LOWER.md`](LOWER.md)，
> call/return 约定见 [`CALL.md`](CALL.md)。

---

## 0. 前端

`module` / `provide` / `require` 在 virtual IR 之前解析完：

- 输出是完整链的 `func` / `data` / `raw`。
- 后端输入里没有 `module`。
- `vregs` / block 名是函数局部，不参与模块可见性。
- 跨模块变量是 `data` + `addr` / `load` / `store`，不是 vreg。
- 内嵌 `asm` 是函数里的 op，边界由 inputs / outputs / clobber 给出。

详见 [`MODULES.md`](MODULES.md) 和 [`ASM.md`](ASM.md)。

---

## 1. 三套数据

### 1.1 virtual IR

```scheme
(func (main)
  (vregs
    (($ a) (b8))
    (($ b) (b8))
    (($ t) (b64)))
  (alloc
    (reserve (native x5))
    (clobber (native x5) (native x6)))
  (entry b0)
  (block b0
    (add ($ t) ($ a) ($ b))
    (term (return ($ t)))))
```

不变量：

- 普通 op 的操作数只有 `($ name)`、整数、`(global chain)`。
- 没有 `(native ...)`（`alloc` 约束区和 `asm` 的
  inputs/outputs/clobber 除外）。
- 没有 `(slot ...)` / `(frame ...)`。
- `asm.code` 是 machine 层，允许 native 指令和局部 label。
- 没有 `allocation`。
- 每个 `($ name)` 都在 `vregs` 中声明。
- CFG 由 block + term 显式给出。

### 1.2 allocation

分配后才有：

```scheme
(allocation
  (($ a) (native x10))
  (($ b) (slot 0))
  (($ t) (native x11)))
```

形状：

```scheme
(vreg location)
```

是二元 proper list，不写 dotted pair。

位置：

```scheme
(native xN)
(slot n)
```

规则：

- car 必须是已声明的 vreg。
- 每个被使用的 vreg 恰好有一个条目。
- 没有 `#f` 占位；未分配就是没有条目。
- `(address-taken)` 的 vreg 必须落到 `(slot n)`，不能只给 `(native xN)`。
- allocation 是映射表，不是代码。

分配层还可以输出 scratch：

```scheme
(scratch (native x5) (native x6))
```

它是 materialize 可以使用的物理寄存器，0 个或多个，不是 vreg 条目，
不进入 `allocation` 表。同一个 scratch 寄存器不能重复列出；共享实现和 pool
在 [`ir/scratch.rkt`](ir/scratch.rkt)。

### 1.3 machine IR

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
    (term (return (native x11)))))
```

不变量：

- 没有 `($ name)`。
- 值操作数是 `(native xN)`、整数、`(global chain)`；内存地址可以用
  `(frame-slot n)`。
- `(slot n)` 只是 allocation location；machine IR 里用 `(frame-slot n)` 表示地址。
- `(slot n)` 不是独立值操作数。
- frame / spill 已经落下或已符号化。
- 不新增虚拟寄存器。

---

## 2. materialization 是唯一的桥

```text
virtual IR + vregs + allocation
        │
        ▼
   materialize
        │
        ▼
machine IR
```

materialize 的职责：

- `($ x)` -> `(native xN)` 或按 slot 拆成 load/store。
- 对 spill 的 vreg 插入 load/store。
- 使用 allocation 给出的 `scratch`，不自己选寄存器。
- 保持 block / term 形状不变。

materialize **不做**：

- 新增虚拟寄存器；
- 改 CFG；
- 选布局；
- 选 `j` / `b`；
- 做 C ABI。

如果某个 pass 需要新增 vreg 或改 CFG，它必须在分配前做，或者重新分配。

当前 materialize（`ir/materialize.rkt`）已经实现：

- 寄存器 vreg -> `(native xN)`；
- slot vreg -> `load` / `store` + scratch；
- `(addr dst ($ x))` -> `(addr machine-dst (frame-slot n))`；
- branch / load / store / binary 的 slot 操作数；
- `call` 的 slot 参数先 load 到 scratch；
- slot 返回值在 call 后 store；
- `return` 的 slot 操作数先 load 到 scratch；
- 输出没有 `($ x)`。

inline `asm`：

- input / output 先做 parallel move；
- code 规范化为 `(asm-code ...)`；
- clobber 作为函数级不可用寄存器；
- code 内 label 是封闭局部 label，固定 4 字节。

---

## 3. 分配前 / 分配后

判断标准：

> **只依赖“这是哪个值 / 宽度 / CFG / def-use”的，放分配前。**
> **一旦依赖“这个值在哪里（寄存器号、slot、地址）”，放分配后。**

### 分配前

| 任务 | 原因 |
| --- | --- |
| CFG 构造 / 验证 | 只需要 block 和边 |
| 不可达 block 删除、空 block 合并 | 会改 CFG |
| 宽度合法化 | 会新增 vreg |
| 常量折叠 | 会删/改 vreg def |
| 立即数 / `const` lowering | 会新增 vreg |
| copy 传播 | 只需要虚拟名字 |
| 内联 | 会新增 vreg 和 CFG |
| address-taken 分析 | 是分配约束 |
| liveness / 干涉图 | 在虚拟寄存器上算 |
| `reserve` / `pin` / `clobber` 收集 | 是分配输入 |

这些 pass 可以新增、删除、重命名 vreg，可以改 CFG。

### 分配后

| 任务 | 原因 |
| --- | --- |
| `($ x)` -> `(native xN)` / `(slot n)` | 需要 allocation |
| `load` / `store` / 算术 -> native 形式 | 只改形式，不新增 vreg |
| spill / reload 插入 | 需要知道哪些 vreg 在 slot |
| frame 偏移分配 | 需要 spill 集合 |
| frame setup / teardown（可选 ABI/平台层） | 需要 frame 和实际寄存器 |
| `call` / `return` lowering | 需要物理位置；具体 ABI 是另一层 |
| `pin` / `reserve` 落实 | 需要实际寄存器 |
| `addr` / 远地址展开 | 依赖最终地址和 scratch |
| block 布局 / fallthrough / `j` / `b` | 依赖最终尺寸和地址 |
| 编码 | 最后 |

这些 pass 只做位置相关改写，不再创造新的虚拟寄存器，不再改虚拟 liveness。

---

## 4. 推荐流水线

```text
source / resolved program
        │
        ▼
driver（frontend + scratch-budget 反馈）
        │
        ▼
virtual IR
  (func / vregs / block / op / term / ($ x))
        │
        ▼
verify-virtual
        │
        ▼
CFG
        │
        ▼
layout-plan               ; block 顺序 / fallthrough 候选；不选 b/j 形式
        │
        ▼
lower-width / lower-const / lower-immediate
        │
        ▼
dce / simplify-cfg
        │
        ▼
liveness / interference     ; 已实现：def-use / live-in / live-out / 干涉
        │
        ▼
allocate                 ; 已实现：allocation 表 + scratch，spill 到 slot
        │
        ▼
materialize              ; virtual IR + allocation -> machine IR
        │
        ▼
machine IR
        │
        ▼
call-plan                 ; 统计 outgoing args / scratch demand
        │
        ▼
frame-layout              ; 使用 outgoing-size
        │
        ▼
lower-ops                 ; frame-slot / load/store / 算术 -> native
        │
        ▼
call-lower                ; prologue / call-target / return epilogue
        │
        ▼
layout-relax             ; 函数内尺寸、b/j/island/return、scratch 请求
        │
        ▼
flat machine items + call-target
        │
        ▼
program-layout           ; 函数 + data 偏移、call-target、addr(global)
        │
        ▼
flat machine items + data bytes
        │
        ▼
encode                   ; 只编码，不展开；输出 relocation
        │
        ▼
link (address data)      ; 回填外部 relocation
```

`const` / 超范围立即数如果会新增 vreg，在 allocate 前展开；只改指令形式的
选择在 `lower-ops`。`addr` / 远形式依赖最终地址，放在 `layout-relax`。

`layout-plan` 只定 block 顺序和 fallthrough 候选；`layout-relax` 才定
b/j 形式、island 和 scratch。这样 backend 不承担展开职责。

scratch 采用统一预算协商：allocate / materialize / lower-ops / layout-relax
都可以报告 `scratch-request`；驱动增大 budget 后重跑。budget 只增不减。
详见 [`layout/README.md`](layout/README.md)。

`raw` 不走 virtual IR / allocation / materialize；它本来就是 machine 层，
直接进入 program-layout / encode 路径。第一版 raw 内部固定 4 字节，不做远跳
relaxation，跨 raw / func 跳转显式报错。

`frame-layout` 把 allocation 的 slot 和 vreg 类型变成 frame 偏移；第一版 stack-first
用 `(address-taken)` + 显式 `addr` / `load` / `store` 表达栈变量。细节见
[`MEMORY.md`](MEMORY.md)。

`layout-relax` 在 materialize / lower-ops / frame-layout 之后，因为只有那时才知道：

- 每条指令的真实尺寸；
- spill 后的指令数量；
- 哪些 block 真正相邻；
- 一条边应该变成 fallthrough、短跳还是远跳。

---

## 5. 不混 C ABI

核心/分配层只使用：

```scheme
(native xN)      ; 物理寄存器：alloc 约束或 machine 值
(slot n)         ; allocation location
(frame-slot n)   ; machine 内存地址
```

不使用：

```scheme
a0 / a1 / a7
ra / sp / fp
jal / jalr 作为调用/返回语义
prologue / epilogue
caller-saved / callee-saved
```

`reserve` / `pin` / `clobber` 是分配约束，不是 C ABI。

如果以后要接 C ABI，它是独立的一层：

```text
core virtual IR
  -> allocate
  -> materialize
  -> optional abi-lower
  -> layout
  -> encode
```

ABI 层可以换，核心 IR 和分配策略都不动。

---

## 6. 边界检查

### verify-virtual

- 输入是 resolved virtual program；顶层只有 `func`（`raw` 走 machine 路径）。
- `vregs` 条目都是 `((vreg) type option ...)`。
- 每个 `($ x)` 都已声明，且没有重复声明。
- 每个 block 恰好一个 term，且是最后一个 form。
- 后继 block 都存在，且在同一函数。
- 不存在跨函数边。
- 普通代码 op 里没有 `(native ...)` / `(slot ...)`；`asm` 的
  inputs/outputs/clobber 和 `asm.code` 除外。
- 没有 `j` / `b` / `label`；`asm.code` 除外（`raw` 不进入 virtual IR）。
- 没有 C ABI 名字。

### verify-allocation

- 每个条目都是 `(vreg location)` 二元 list。
- key 是已声明 vreg。
- location 是 `(native xN)` 或 `(slot n)`。
- 每个被使用的 vreg 恰好一个条目。
- 没有重复 key。
- `(address-taken)` 的 vreg 必须分配 `(slot n)`。
- `pin` 的 vreg 必须落在指定物理寄存器。
- 普通 vreg 不能落进 `reserve` 的寄存器；显式 pin 除外。
- `scratch` 必须合法，且同一个寄存器不能重复。

### verify-machine

- 没有 `($ x)`。
- 值操作数是 `(native xN)`、整数、`(global chain)`；内存地址可以用
  `(frame-slot n)`。
- `(slot n)` 不是独立值操作数。
- frame / scratch 合法；scratch 不能重复。
- block / term 形状仍然合法。
- `j` / `b` / `label` 还没有进入机器函数；`asm.code` / `raw` 除外。
- 有 frame 时，`(frame-slot n)` 必须在 frame 里有条目。

实现：[`ir/verify-machine.rkt`](ir/verify-machine.rkt)，测试：
`test/verify-machine-test.rkt`。

这三组检查是后面每一步验证的入口。
