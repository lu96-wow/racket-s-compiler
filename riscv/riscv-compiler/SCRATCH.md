# scratch 寄存器选择：设计讨论记录

> 状态：讨论记录。本文只记录判断和方案，不改变当前实现。
>
> **§1–§9 是第一轮（"后端能不能自己找 scratch"）的记录；
> §10 是第二轮（"前端和后端怎么协商"）的结论，凡与前面冲突以 §10 为准。**
> §10.0 有一张"哪条早期结论被修订"的清单。
>
> 相关文件：
> [`CONSTRAINTS.md`](CONSTRAINTS.md)、
> [`layout/forms.rkt`](layout/forms.rkt)、
> [`layout/layout.rkt`](layout/layout.rkt)、
> [`relax/relax.rkt`](relax/relax.rkt)、
> [`encode/encode.rkt`](encode/encode.rkt)、
> [`analyze/cfg.rkt`](analyze/cfg.rkt)、
> [`flow/DESIGN.md`](flow/DESIGN.md)。

## 1. 问题

RISC-V 的远跳转 / 远分支在某种形式下需要 scratch 寄存器：

- `(branch-indirect <cond> rs1 rs2 L)`：反向条件分支 + `auipc` + `jalr`，需要 base；
- `(jump-far x0 s L)`：link 是零寄存器，`auipc` 没有落点，需要 scratch；
- `(jump-far link s L)` 且 link 非零时不需要 scratch，link 自己就是 base；
- 远 `la`、大 offset 的 `la-frame`、`jump-pcrel-far` 等也需要 scratch。

当前设计已经能判断“需不需要 scratch”，但“用哪一个寄存器”还没有实现。问题：

> 能不能不依赖前端选寄存器，由后端顺着基本块 / 控制流自动找一个空寄存器来填 scratch？

以及：

> 如果后端不能完全自动，应该怎么和前端配合？

## 2. 结论摘要

> 本节是**第一轮**的摘要，其中第 5 条（"前端保证 1–2 个池"）的具体形态已被
> [§10](#10-第二轮讨论协商模型结论) 取代：留几个、怎么声明、怎么判断，都按 §10 走。

1. **“在块边界处理远跳、块内保持短跳”不能避开寄存器选择。**
   当前 IR 里所有 branch / jump / indirect / trap 本来就是块终结指令，
   远形式已经位于块边界。问题不在“把指令放到哪里”，而在“这个出口边上哪个寄存器是 dead”。

2. **扫 CFG 块结构本身不能判断“空 reg”。**
   `analyze/cfg.rkt` 只提供块、后继、fallthrough、root，没有 use/def，也没有
   live-in / live-out。块内没出现过的寄存器可能从前驱带进来、在后继使用。

3. **真正的自动选择需要完整 liveness。**
   需要显式 + 隐式 use/def、edge-sensitive liveness、函数/region 边界、
   调用 clobber、ABI、root live-in。即使全都有，root、间接入口、外部入口
   仍可能保守到“所有寄存器都 live”，从而找不到 scratch。

4. **自动选择不能替代 reserved scratch。**
   它可以作为 opt-in 优化，但必须有 fallback：失败时报错，或回退到前端保留的 pool。

5. **最稳的组合是：前端保证 scratch 池，后端在池里选并填洞。**
   前端不需要逐点选寄存器，只需要保证 1–2 个 caller-saved temp 不被普通值分配使用；
   后端 `scratch-fill` 负责取池、检查冲突、填 hole。这也符合当前 `CONSTRAINTS.md`
   的分段模型。

6. **想减少 scratch 需求，优先考虑代码模型 / 布局，而不是猜寄存器。**
   把条件分支和局部 `j` 控制在 `jal` 范围内，大部分长跳就不需要 scratch；
   远调用 `jump-far ra` 也不需要 scratch。剩下远尾跳、远 `la` 再走 reserved scratch。

## 3. 当前实现事实

当前流水线：

```text
analyze -> dce -> relax -> bind-labels -> encode
                    │
                    └── layout 在 relax 内部反复跑
```

scratch 相关处理：

| 位置 | 事实 |
| --- | --- |
| `layout/forms.rkt` | `scratch-hole?` 根据形式 / link 判断是否缺 scratch；它只判定“缺不缺”，不选择“用哪个”。 |
| `layout/layout.rkt` | `check-scratch` 把缺口报成 `(scratch-hole 段 偏移 item origin)` request。 |
| `relax/relax.rkt` | 只消费 `needs-far`，把控制转移升成更大的定长形式；`scratch-hole` / `la-too-far` 原样保留。 |
| `encode/encode.rkt` | 遇到 `scratch-hole?` 仍为真的 item 直接报错，不会猜寄存器。 |
| `riscv-help/scratch.rkt` | 检查 scratch 非零、数量够、多个 scratch 互不相同。 |
| `riscv-help/*` 全体 | **不认 ABI 名**：只处理 `x0..x31`；`ra`/`sp`/`gp`/`t*` 一律由前端/IR 给（`test/no-abi-test.rkt` 守这条）。 |
| `riscv-help/la.rkt` | far `load-pcrel` 要求 scratch 不等于 `rd`；`la-frame` 要求 scratch 不等于 `rd` / `base`。 |

当前没有：

- `scratch-fill` pass；
- regalloc / spill；
- CFG liveness；
- 函数边界 / ABI 模型；
- 间接入口的 live-in 信息。

`CONSTRAINTS.md` 已经规定：

- 依赖 offset 的尺寸变化进入 `relax` 固定点；
- `relax` 只做定长形式替换，尺寸单调增长；
- `scratch-fill` 在 `relax` 之后，尺寸不变，只填 reserved scratch；
- 不在 `relax` 之后插入 spill / load / store / label；
- 不支持 relax 和 scratch/spill 的联合固定点。

## 4. 为什么“块边界”不等于“有空寄存器”

### 4.1 块内没出现 ≠ dead

例子：

```scheme
B0:
  addi t0 x0 7
  beq  L a0 x0      ; 这条变远

B1:
  add  t1 t0 t0
L:
  add  t2 t0 t0
```

在 `B0` 的终结指令处，`t0` 没有出现在终结指令里，但它在 `B1` / `L` 仍然 live。
如果按“块内没出现”选 `t0` 当 scratch，就会破坏活值。

正确判据：

> 在 scratch 被写入的那条路径上，该寄存器从写入点到下一次定义之间没有被使用。

这是 liveness，不是块内文本扫描。

### 4.2 块级 live-out 会丢失 edge 信息

`branch-indirect` 的展开形状是：

```text
反向条件分支  -> 跳过后面的远跳序列
auipc scratch, hi
jalr  x0, scratch, lo
```

scratch 只在**原分支 taken 的那条边**被写。原分支 fallthrough 走反向分支，直接跳过，
不会碰 scratch。

因此可能出现：

- `t0` 在 fallthrough 后继里 live；
- `t0` 在 taken 目标里 dead。

这时 `t0` 可以当 scratch。  
但如果只看“块边界所有后继 live-out 的并集”，会误判 `t0` live，从而保守地找不到寄存器。

反过来，只看“块内没出现”又会把 taken 目标里 live 的寄存器误用。  
所以需要的是 **edge-sensitive liveness**，不是简单的块级扫描。

### 4.3 root / 间接入口 / 外部入口

`analyze` 的 root 包括：

- 程序入口；
- 有间接跳转时，地址被取过的块。

间接跳转目标、外部调用进来的块，都可能带着任意 live-in 寄存器进入。
如果后端没有函数签名、ABI、live-in 声明，保守做法只能是：

> root 处所有寄存器都视为 live。

那么 root 块里的远跳就找不到“确定空”的寄存器。  
这不是实现细节，而是信息不足：汇编后端不知道外部世界在入口处放了什么寄存器。

### 4.4 隐式 use/def 和 ABI

很多寄存器读写不在显式操作数里：

- `jal ra, ...` 写 `ra`；
- `ret` 读 `ra`；
- `ecall` / `ebreak`；
- `jalr` 的 link；
- `sp` / `gp` / `tp` 的约定；
- 调用点的 caller-saved clobber；
- callee-saved 寄存器即使在本函数内 dead，也可能需要按 ABI 对调用者保持。

如果 liveness 只扫显式操作数，会直接算错。  
即使算对函数内 liveness，后端还必须有 ABI 模型，才能知道哪些寄存器可以随便当 scratch。

### 4.5 不能在跳走之后 restore

远跳的 scratch 用在最后一条 `jalr` 上。可以在前面保存一个 live 寄存器，
但**不能在跳走之后恢复它**：

```text
save s, off(sp)
auipc s, hi
jalr x0, s, lo     ; 控制流已经离开，没有机会 restore
```

如果先 restore 再跳，scratch 又被覆盖了。条件远分支的 taken 边同理。

所以“在边界插入 save/restore，把任意寄存器变成 scratch”并不成立。
它只能使用一个在该出口边上真正 dead 的寄存器，或者使用前端保证保留的 scratch，
或者引入 trampoline / 保存恢复协议——后者已经超出“尺寸不变地填操作数”的后端范围。

### 4.6 插入变长指令会破坏 relax 契约

在块边界插入变长的 save/restore / trampoline 会：

- 改变尺寸；
- 可能让原本够得着的分支变远；
- 需要重新 layout，甚至反复；
- 超出 `scratch-fill` 的职责。

`CONSTRAINTS.md` 明确拒绝 relax 和 scratch/spill 的联合固定点。
因此这类插入只能放在 `relax` 之前，或者进入 `relax` 固定点，不能作为
`relax` 之后的自动 scratch 方案。

## 5. “块内短跳转 / 块边界插入”的具体评估

### 5.1 当前 IR 里没有块内控制转移

`analyze` 的切块规则是：branch / jump / indirect / trap 之后一定开新块。  
所以 branch / jump 天然就是块的最后一条指令。  
“块内用短跳转”在这个 IR 里没有对应物；远形式本来就已经在边界上。

### 5.2 短不短取决于布局距离，不取决于 CFG 嵌套

一个很小的块，终结分支也可能指向很远的块。  
`layout` 里有显式 `place` 和段起点，块可以被放到很远。  
所以“块内 / 块边界”不能保证距离短；只有 **placement / 代码模型** 才能保证。

### 5.3 真正能消除 scratch 的方向是“消掉远形式”

如果代码模型能保证：

- 每个 region / function 的代码小于 `jal` 范围（约 ±1 MiB）；
- 条件分支目标不跨出 region；
- 局部 `j` 目标不跨出 region；

那么：

- 条件分支最多升到 `branch-far`（反向分支 + `jal`），不需要 scratch；
- 局部 `j` 最多是 `jal x0`（±1 MiB），不需要 scratch；
- 普通远调用 `jump-far ra` 用 link 自己当 base，不需要 scratch。

剩下真正需要 scratch 的主要是：

- `jump-far x0` 的远尾跳；
- 超过约 ±1 MiB 的条件分支（升到 `branch-indirect`）；
- 远 `la`；
- 大 offset 的 `la-frame`；
- 超过约 ±2 GiB 的 PC-relative 跳转。

也就是说，**大部分长跳 scratch 可以通过布局 / 代码模型避免**。
这比“后端扫 CFG 猜寄存器”更可控，但仍有边界情况，比如远尾跳和远 `la`。

## 6. 如果一定要后端自动，需要哪些前提

后端自动选 scratch 不是绝对不可能，但需要把它从“汇编器”升级成
“知道寄存器语义的编译器后端”。

### 6.1 每条 item 的 use/def

- 显式操作数；
- 隐式读写：link、`ra`、`sp`、`gp`、`tp`、call clobber、trap；
- 压缩形式、伪指令展开后的真实读写；
- `la` / `li` / 远形式展开后的读写。

### 6.2 函数 / region 边界

- 入口 live-in；
- 外部入口、间接跳转目标的保守 live-in；
- 调用点的 caller-saved clobber；
- callee-saved 的 ABI 保持要求。

### 6.3 edge-sensitive liveness

- 不能只算块级 live-out；
- 要能回答“在这个 scratch 被写的具体边上，哪些寄存器 dead”。

### 6.4 候选寄存器集合

- 只考虑 caller-saved temporaries，例如 `t0`–`t6`；
- 排除 `x0`、`sp`、`gp`、`tp`；
- 排除 branch 操作数、link、`la` 的 rd / base；
- 多个 scratch 时互不相同；
- 遵守 ABI / 平台保留寄存器。

### 6.5 opt-in 元数据

当前后端是汇编器，不能假设所有输入都是编译器生成的闭世界代码。
手写汇编、外部入口、自定义 ABI、内联汇编都可能让“dead”判断失效。

因此自动模式应该由前端显式开启，并保留 reserved pool 作为 fallback。

### 6.6 填洞后仍要验证

- `scratch != x0`；
- 不重复；
- 不与 rd / base / link 冲突；
- 在声明的池里；
- 不能通过 liveness 验证的部分，必须由前端保证。

### 6.7 仍然会失败的情况

即使这些全做了，仍然会出现：

- root 块所有寄存器保守 live；
- 间接跳转目标所有寄存器保守 live；
- 所有 caller-saved temp 都 live；
- 没有候选。

所以自动选择**不能作为唯一机制**，必须有一个“失败时报错或回退到 reserved scratch”的出口。

## 7. 结合前端选择 scratch 的方案

### 方案 A：前端保留池，后端填洞（推荐）

这是当前 `CONSTRAINTS.md` 的意图，也是改动最小、最稳的路线。

前端 / 寄存器分配层：

- 每个 function / region 保留 1–2 个 caller-saved temp，例如 `t5` / `t6`；
- 普通值分配不使用它们；
- 不需要知道具体哪些远跳点，因为后端会在需要时填。

后端 `scratch-fill`：

- 从池里取寄存器；
- 检查非零、不重复、不与 rd / base / link 冲突；
- 填 `(branch-indirect s ...)` / `(jump-far x0 s L)` / 远 `la`；
- 不改尺寸，不插代码；
- **不判断池里的寄存器是不是 caller-saved**。池的成员由前端定，
  后端若内置一份 `t0..t6` 白名单，等于把 ABI 策略硬编码进汇编层
  （也和第 6.4 条的"候选集"一样，属于前端/ABI 层的信息）。

优点：

- 前端不需要逐点选；
- 后端不需要 liveness；
- 安全边界清晰：前端保证“这个寄存器可以随便用”，后端保证“用得合法”。

代价：

- 整个 function / region 少一个可分配寄存器；
- 但只在需要远形式的 region 才值得保留。

### 方案 B：条件预留 / 代码模型

不是所有函数都需要 scratch。可以根据代码模型条件预留：

- 如果函数 / region 很小，且所有控制转移目标都在短范围内，就不保留；
- 如果预计会超过 `jal` 范围，或存在远尾跳 / 远 `la`，就保留；
- 也可以在编译前做一次尺寸上界估计，决定是否给这个函数加 scratch 池。

这比“每个函数都固定留一个寄存器”更省，但需要代码模型或尺寸估计。

### 方案 C：两遍编译

第一遍不让前端预留 scratch，正常跑 relax：

- 如果后端报告没有 `scratch-hole`，完成；
- 如果有 `scratch-hole`，说明这个程序需要 scratch，前端带 scratch 池重跑一遍。

优点：

- 前端不需要逐点选；
- 后端不需要 liveness；
- 只在真正需要时付出重编译成本。

缺点：

- 是 driver 层的两遍，不是单遍流水线；
- 需要缓存 / 避免重复工作。

这是很自然的“结合前端”的方式：**后端报告需求，前端提供池，后端再填**。

### 方案 D：前端提供 liveness / ABI 元数据，后端 opt-in 自动选

如果确实想让后端自动选，可以让前端传：

- 函数的 live-in；
- 每条 item 的 use/def；
- 调用 clobber 集合；
- 可用的 scratch 候选集合；
- 哪些块是外部 / 间接入口。

后端在 `relax` 之后做 edge-sensitive liveness，选 dead 的 caller-saved temp 填洞。
这可以作为优化模式，但仍然保留 reserved pool 作为 fallback。

适合“闭世界、编译器生成、元数据完整”的场景，不适合作为通用汇编器的默认行为。

### 方案 E：全局固定 scratch 约定

约定 `t6` 永远不作普通分配，远形式一律用它。

- 对编译器生成代码很有效；
- 完全不需要 CFG 分析；
- 代价是全局少一个寄存器；
- 手写汇编用户必须知道这个约定，或者通过选项关闭。

### 方案 F：交给 linker / veneer

如果以后有 reloc / linker，可以把远分支展开交给 linker。

但 linker 的 veneer 仍然需要 scratch，或者需要一套保存 / 恢复协议；
它不是“无寄存器成本”的魔法，只是把选择点从汇编器移到链接器。
当前项目还没有 reloc / linker，这条路线属于未来。

## 8. 推荐路线

1. **短期**
   - 实现 `scratch-fill`，只消费前端提供的 reserved scratch 池；
   - 不引入 CFG liveness；
   - 保持 `CONSTRAINTS.md` 的“relax 之后、尺寸不变、不插代码”。

2. **中期**
   - 用代码模型 / 尺寸阈值决定是否需要池；
   - 远调用 `jump-far ra` 用 link 自己当 base；
   - 尽量把条件分支和局部 `j` 限制在 `jal` 范围内。

3. **如果确实要自动**
   - 作为 opt-in 模式；
   - 前端提供 use/def、ABI、函数边界、root live-in；
   - 后端做 edge-sensitive liveness；
   - 找不到 dead 寄存器时回退到 reserved pool 或报错；
   - 不要把它作为通用汇编器的默认行为。

4. **长期**
   - 如果引入 reloc / linker，再考虑 veneer / 链接器松弛；
   - 仍然需要明确的 scratch 约定。

## 9. 新 pass 自检清单

以后如果实现 `scratch-fill` 或自动 scratch 选择，先回答：

1. 它是在 `relax` 之前还是之后？
2. 它会改变尺寸吗？
3. 它会插入 label / 指令吗？
4. 它需要 liveness 吗？如果需要，use/def 和 root live-in 从哪来？
5. 它知道 ABI 的 caller-saved / callee-saved 吗？
6. 间接跳转目标和外部入口怎么保守处理？
7. 找不到 scratch 时怎么办？
8. 它填的寄存器在声明的池里吗？
9. 它能通过 `encode` 的 offset / size 断言吗？
10. 它是否仍然遵守 `CONSTRAINTS.md` 的分段模型？

---

# 10. 第二轮讨论：协商模型（结论）

前面 §1–§9 回答的是"后端能不能自己找 scratch"，结论是"不能，必须和前端配合"。
这一节把**配合的形态**定下来：协商什么、用什么数据、谁在什么时候知道什么。

## 10.0 被修订的早期结论

| 早期说法 | 现在的结论 | 为什么 |
| --- | --- | --- |
| §2.5 / §7 方案 A："前端保证 1–2 个 caller-saved temp" | **细化**：前端按 region 保留**具体某个寄存器**，数量是 **0 或 1**；"caller-saved 类别"这种判断留给前端，后端不认 ABI | §10.3 论证 k=1 充分；后端认 ABI 会把策略硬编码进汇编层 |
| §6.4："候选集 = `t0`–`t6`" | 后端不维护候选集，池由前端在声明里给出 | 同上 |
| §7 方案 E："全局固定 `t6`" | 只有**前端/target**能这么定；后端不接受默认值 | `Zicfilp`（抢 `t2/t3`）、`Tag_RISCV_x3_reg_usage`（`x3` 可被改成 shadow stack）都说明"固定"是平台约定，不是 ISA |
| 第二轮的中间稿："填池是纯语法补丁" | **错，已推翻**：改 k 会改 spill ⇒ 改尺寸 ⇒ 需求可能变。第二遍必须**重新着色 + 重跑整条流水线** | §10.7 |
| 第二轮的中间稿："region 尺寸上界 < 4 KiB 就不需要" | **不严谨**：需求由**距离**决定，距离可能跨 region。要用**每个 label 的地址区间** | §10.6 |
| 第二轮的中间稿："用最近的前导 label 当作用域" | **错**：不稳定的启发式 | §10.5 三个反例 |
| 第二轮的中间稿："池表 + 链前缀匹配" | 放弃：依赖命名纪律。池直接放进 region 声明里 | §10.4 / §10.5 |

## 10.1 环是什么，为什么图着色不能延后到 layout 之后

两个事实互为输入：

| 事实 | 谁知道 | 依赖 |
| --- | --- | --- |
| 哪些站点需要 scratch | 后端（`layout` 算距离） | 站点位置 ← 尺寸 ← 形式选择 ← `relax` |
| 哪些寄存器在这些点上是死的 | 前端（着色 / liveness） | 与布局无关 |

"把图分配推迟到 layout 之后"**不可行**，理由是一条单向的尺寸链：

```
着色改尺寸（少一个可分配寄存器 ⇒ 多几条 spill）
  ⇒ layout 依赖尺寸
  ⇒ 尺寸变了就要重新 layout
  ⇒ layout 又决定"哪里需要远形式"
  ⇒ 又改变着色压力
```

这正是 `CONSTRAINTS.md` 里"会改尺寸的寄存器分配必须在 `relax` 之前"的来源。
（LLVM 的 `insertIndirectBranch` 是在 branch relaxation 里边迭代边插 spill 的，
那意味着 **relax 和插码做联合固定点** —— 本项目的 `CONSTRAINTS.md` 明确拒绝这条。）

**但环可以被切断**，因为两个事实的"可逆性"不同：

- "哪些站点需要"随尺寸单调、可重算；
- "哪些寄存器可用"是前端的**分配决定**，对任意给定程序都能答。

所以协商量不是"哪个站点用谁"，而是 **"每个 region 留几个寄存器"** —— 一个小、离散、单调的量。

## 10.2 协商量：每个 region `k ∈ {0, 1}`

```
k_R = 0   这个 region 里不会出现需要 scratch 的形式（前端判过，见 §10.6）
k_R = 1   留了 1 个寄存器，后端可以随便用
```

后端**不需要**知道"这个 region 有几个站点"——因为一个就够了（§10.3）。

## 10.3 为什么 k=1 充分（所以"用完"不存在）

两个事实合起来：

1. 单个站点只需要一个寄存器在 `auipc` → `jalr`（两条相邻指令）之间活着；
2. 前端承诺"这个寄存器在**整个 region** 内从未被分配" ⇒ 它在 region 的**每一点**都死。

于是 region 内**所有**站点共用同一个寄存器即可。

补充一条更硬的论证，说明"约束冲突"也不会发生：站点对寄存器的额外限制
（`la-far` 要求 `tmp ≠ rd`、`branch-indirect` 要求 `s ∉ {rs1, rs2}`）里出现的寄存器
**全都是被分配过的值寄存器**；而保留的寄存器从未被分配 ⇒ 不可能出现在 `rd`/`rs1`/`rs2` 位置。
所以 `forbid ∩ 保留集 = ∅` 是**自动成立**的，不需要逐个站点挑。

（例外只有一个：region 里混进了手写汇编、自己用了那个寄存器。那属于违约，
由将来的 `(pool-register-used 链 reg)` 检查抓，见 §10.9。）

**唯一需要 k=2 的情况**：这个 region 连 1 个寄存器都腾不出来（见 §10.10 的出路）。

## 10.4 声明形式：声明"留出来的"，不是"用掉的"

```racket
(use-reg (lib f) (x28))    ; 承诺: x28 在这个 region 内从未被分配 ⇒ 每一点都死
(use-reg (lib f) ())       ; 承诺: 一个都没留
```

为什么不用"列出用掉的寄存器、其余随便用"（补集模型）：

| | 声明用掉的（补集） | 声明留出来的（正向） |
| --- | --- | --- |
| 语义 | "不在列表里就是死的" | "列出来的这些，我保证没用过" |
| 出错方式 | 漏写一个 ⇒ **静默**用坏活值 | 写错/多写 ⇒ 可检查 |
| 可验证性 | 要扫全部指令重建使用集 | 只需查"这个寄存器在 region 内出现过吗" |

## 10.5 region 是**结构属性**，不是"最近的前导 label"

三个反例（说明为什么不能靠启发式）：

1. **粒度不对**：每个基本块都以 label 开头 ⇒ "最近 label" 最多一个 BB，而保留是按函数/region；
2. **过 pass 不稳定**：`dce` 的 `merge-empty-blocks` 会把两个 head **拼成一个**
   （`(block ((a) (b)) …)`），同一个站点在 dce 前后会换名；
3. **一址多名**：`(label a f)` 同一位置两个名字，"最近"选不出唯一答案。

所以 region 的身份**由前端显式给出**，然后作为**块属性**一路带走：

| 层 | 形式 | 谁产出 / 谁消费 |
| --- | --- | --- |
| 前端 IR | `(use-reg 链 (池…) item …)` 嵌套 | 前端写（人能读） |
| `flatten` | 摊平 + **平衡的**记号 `(region 链 (池…))` / `(end-region)` | flatten 生成（配对由它保证，不靠人） |
| `analyze` | 记号**不进 item**，变成块属性 `(block (region 链 (池…)) (head…) item …)` | analyze 用栈解析嵌套 |
| `dce` | 属性跟着块走（`assemble` 保留；合并空块时取**非空块**的那个） | 空块没有站点，所以不会冲突 |
| `relax` | `apply-edits` 只换 item，块属性不动 | 天然稳定 |
| `layout` | 逐块走时知道当前 region ⇒ 写进 `scratch-hole` request | **"保留到 layout"的落点** |
| `scratch-fill`（未实现） | 从站点的 region 里取池，不需要查表/前缀匹配 | — |
| `encode` | 完全不知道 region | — |

要点：**源形式是嵌套的，携带形式是字段。** 嵌套只在 `flatten`→`analyze` 之间活一小段
（而且是 flatten 生成的，配对不可能出错），之后全是块字段。

**硬规则**：不在任何 region 里的代码不许出现需要 scratch 的形式；真需要就在外层加一个 region。
这样"池从哪来"永远有唯一答案，不需要 default、不需要 fallback。

## 10.6 上界：可以在**任何布局之前**算出来（区间算术）

前提：后端必须能给出**每个 item 的最大尺寸**。这是"所有远形式都定长"换来的。

| item | 当前尺寸 | 最大尺寸 |
| --- | --- | --- |
| `(beq …)` 等 | 4 | 12（→ `branch-far` → `branch-indirect`） |
| `(jal …)` | 4 | 8（→ `jump-far`） |
| `(la rd 链)` | 8 | **40**（→ `la-far`，`far-la-size`，已实现） |
| `(li rd k)` | 由 k 精确决定 | 同左（不需要上界） |
| `(align n)` | 由游标定 | 最多补 `n−1` |
| `(c.*)` | 2 | 4 |

> `la-far` 必须是定长，这里就看出回报了：如果它是变长的（`li` 的长度取决于 delta），
> 这张上界表就不存在，前端永远"判不了"。见 `CONSTRAINTS.md` §7。

三个输入，前端/驱动都已经有：**① 上界表**（后端的静态数据）；
**② 段的地址与容量**（`layout-spec` 是输入）；**③ `place` 声明的顺序**。

算法（按 **label** 算，不按 region —— 因为距离可能跨 region）：

```
对每个 label L:
  lo(L) = 它前面所有 item 的最小尺寸之和      (align 按 0 算)
  hi(L) = 它前面所有 item 的最大尺寸之和      (align 按 n−1 算)

对每个控制转移 S → L（以及 la → L）:
  距离上界 = hi(L) − lo(S)
  距离下界 = lo(L) − hi(S)
```

- 上界 ≤ 阈值 ⇒ **一定**不需要 ⇒ 该 label 的 region 可 k=0；
- 下界 > 阈值 ⇒ **一定**需要 ⇒ k=1；
- 夹在中间 ⇒ 保守 k=1。

两条最简充分条件（覆盖大多数真实镜像）：

1. **整份镜像上界 < 1 MiB** ⇒ 所有条件分支最多升到 `branch-far`（用 `jal`）、
   所有 `jump-far link`（link 非零）都用 link 自己当 base ⇒ **全部 region k=0**；
2. **`la` 的地址都落在 ±2 GiB 内**（代码模型 + 数据段地址给定）⇒ 不会出现 `la-far`。

坑：

| 坑 | 处理 |
| --- | --- |
| `align` 放大上界 | 按 `n−1` 累加，且影响其后所有区间 |
| 同一 region 的块被 `place` 拆到不同段 | 所以按 label 算区间；region 只用来汇总 k（任一 label 需要 ⇒ k_R=1） |
| `dce` 删/并块 | 只会变小 ⇒ 上界仍成立（安全方向） |
| 外部符号（`externs`） | 地址已知就直接算；`#f` 已报 `unlinked-external`，不参与 |
| 上界判断失准 | **以 layout 为准**：改成 k=1 重跑；上界是优化，不是权威 |

权威顺序必须写死，否则会出现两个真相：

> **上界只用来决定 k（着色时留几个）；真正的需求永远由 `layout` 的 `scratch-hole` 决定。**
> 不一致时按 layout 走 + 迭代一轮。这样 bound 算错只会多一轮编译，不会产出错代码。

## 10.7 握手协议：需求是**产物**，不是异常

三个 s-exp，对应握手的三个位置：

```racket
;; ① 前端写（嵌套、人能读）
(use-reg (lib f) (x28)
  (label (lib f))
  …)

;; ② layout 的 request（在现有 4 项后加一项 region；不是启发式猜的）
(scratch-hole c #x14
              (branch-indirect beq x10 x11 (lib g))
              (code 0 2)
              (region (lib f) (x28)))

;; ③ scratch-fill 的产物（dry-run 的输出；driver 要能读它）
(scratch-demand
  (region (lib f) needs 1)          ; 池是空的 ⇒ 这一行就是“请给我 1 个寄存器”
  (site (region (lib f))
        (at c #x14)                 ; 人看的坐标
        (origin code 0 2)           ; 机器坐标（块/项）
        (item (branch-indirect beq x10 x11 (lib g)))))
```

`needs 1` 是汇总（§10.3），`item` 已包含形式语义（谁不能被选），所以需求里不重复存 `forbid`。

失败仍然由 `encode` 兜底（requests 非空 ⇒ 拒绝出产物），行为不变。

协议：

```
① 前端每个 region 按上界定 k，着色（可用寄存器 = 31 − Σk）
② layout/relax：算距离 ⇒ 站点集 ⇒ scratch-fill：从 region 的保留寄存器里填
③ 没填上？只可能是某个 k=0 的 region 判错了
   ⇒ 改成 k=1（或者腾不出就按 §10.10 处理）
   ⇒ 前端**重新着色** + 重跑整条流水线      ← 不是“补个字段”
```

**第二遍必须是重新着色 + 重跑整条流水线**，因为改 k 会改 spill ⇒ 改尺寸 ⇒ 需求可能变。
（这条推翻了中间稿里"填池是纯语法补丁"的说法。）

收敛性：把"哪些 region 取 k=1"看成决策集，它**只增不减**，上界是 region 个数
⇒ 单调有界，必然收敛。常见情况是**零轮**（§10.6 的两条充分条件）或**一轮**。

## 10.8 可以延后的是什么、不能延后的是什么

| 决定 | 能延后吗 | 说明 |
| --- | --- | --- |
| 哪个值放哪个寄存器（着色） | **不能** | 改尺寸（spill），layout 依赖尺寸 |
| 每个 region 留几个（k） | **不能**，但可以**提前用上界判**（§10.6） | 它同样是着色的输入 |
| 站点上具体用哪个寄存器 | **能** | 从 region 的保留集里挑，不改尺寸（`CONSTRAINTS.md` 的第三类） |
| 是否需要 reloc / veneer | 以后再说 | 引入 linker 后才谈 |

## 10.9 不变量与自检（可机械检查）

1. `(region …)` / `(end-region)` 必须配平；配不平 `analyze` 报错。
2. 块属性在 `dce` 合并时取**非空块**；两个非空块永不合并 ⇒ 无歧义。
3. 站点没有 region 却有 hole ⇒ `(scratch-hole 无 region …)` problem，提示"加一个 region"。
4. **填完尺寸不变**：`scratch-fill` 重跑 `layout` 后，每段 `size`、每条 anchor 的
   `(段, 偏移)` 必须与填充前逐项相同；出现新的 `needs-far` 就是 bug。
5. 只从保留集里取：非零、在池里、不重复。
6. （将来）`(pool-register-used 链 reg)`：region 内的指令真的用了池里的寄存器 ⇒ problem。
   把"前端承诺"变成可验证的，比信任更好。
7. 确定性：同输入同池 ⇒ 同字节；站点按 (段, 偏移) 升序处理，池里按声明顺序取第一个可用。

## 10.10 留不出寄存器时的三条出路

1. **拆 region**（把大函数切成两个着色范围）—— 首选，代价是跨切片的活值落栈；
2. **Veneer**：远分支的落点放进一个**专用小段**，那段由后端/链接器生成、只用固定寄存器
   （前端可以放心声明"这里 x6 你不用管"）。把"必须留寄存器"关进一个已知的小盒子；
   这是 linker 的标准做法，引入 reloc 层之后再谈；
3. **报错**：`(scratch-hole …)` + 站点清单。**绝不猜**。

## 10.11 明确不做

- 后端扫 CFG 找"块内没出现过"的寄存器（§4 已否）；
- 后端维护 ABI 类别（caller-saved 白名单）或默认池（`t1`/`t6`）；
- 用"最近 label"当作用域；
- 池表 + 链前缀匹配（依赖命名纪律）；
- 缺池时给个默认值；
- relax 与插码的联合固定点（`CONSTRAINTS.md` 明确拒绝）。

## 10.12 实现落点与顺序

**第一步：把数据面定死（不动填充）**

| 位置 | 改动 |
| --- | --- |
| `flatten` | 认 `(use-reg 链 池 item …)`，摊平成 `(region 链 池)` / `(end-region)` |
| `analyze` | region 栈；记号不进 items；新块带属性 |
| `program` / `block` | 多一个字段 ⇒ `make-block`、`program->sexp`、`sexp->program` |
| `dce` | `assemble` / `merge-empty-blocks` 带字段 |
| `relax` | `apply-edits` 重建块时带字段 |
| `layout` | `measure` 记当前 region，写进 `scratch-hole` request（第 5 项） |
| 新 `(scratch-demand …)` 产物 | 由 `relax` 收尾时汇总 requests 产出（`scratch-fill` 之后再接管） |

做完这一步，"后端向前端要什么"就是一份稳定的 s-exp，前端可以照着做配合。

**第二步：填**

| 位置 | 改动 |
| --- | --- |
| `layout/forms.rkt` | `max-item-size`（和 `item-size` 并列的上界表） |
| 新纯函数 | `(scratch-bound …)`：区间算术 ⇒ 每个 region 的 k 建议（可单测，不碰流水线） |
| 新 stage `scratch-fill` | 读 request + 池 ⇒ 填 program（复用 `relax` 的 `apply-edits`）⇒ 重跑 layout ⇒ 断言 §10.9 第 4 条 |

**第三步（可选）**：`pool-register-used` 检查、veneer、reloc 层。

## 10.13 待定

1. `(use-reg …)` 的语法细节：池是必写还是可省（可省 = k=0，还是要显式 `()`）？
2. region 名字是否必须等于某个 label 链（便于诊断），还是任意链都行？
3. 一个 region 内是否允许"再嵌套一个 k=1 的子 region"以外的用法（例如同一 region 声明两个池）？
4. `max-item-size` 对 `(li rd k)` 用精确值即可，但 `align` 的上界还要考虑段起点对齐，
   §10.6 的区间算术实现时要明确"段起点未知时按 0 算"还是"按最坏对齐算"。
5. `scratch-demand` 要不要带上"镜像上界"和"判据来源"（bound / layout），便于诊断为什么建议 k=1。
