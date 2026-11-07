# scratch 寄存器选择：设计讨论记录

> 状态：讨论记录。本文只记录判断和方案，不改变当前实现。
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
- 不改尺寸，不插代码。

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
