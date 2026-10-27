# L5 布局计算

## 0. 上游: L3 分析 / L4 死代码消除

label 不等于块：块由 **leader**（程序开头、**控制转移的目标 label**、`ends-block?` 指令之后）决定。
非目标的 label 不是边界，它只是块内的位置标记；一个块可以没有 label，也可以有多个名字（块头连续多条 label）。按 label 搬代码会把「块」和「位置」混为一谈；更危险的是**顺序执行（fallthrough）**被段切断时，按名字搬动的布局层根本看不见。

所以：**L3 只做分析并输出块列表（不改程序），L4 做死代码消除（会改控制流），
L5 按块放置并检查 fallthrough 没被剪断。**

L4 的 pass：`drop-unreachable` → `drop-transfers-to-next-block` → `merge-empty-blocks`，
每个都同步修 `succ` / `fallthrough`，跑到不动点。

## 1. 块列表（L3 输出、L4 输入输出、L5 输入）

块是 s-exp，两部分：身份 + 程序。

```racket
(block <头 label 链列表> item ...)      ; (block ((prog1 main)) (lwu t0 sp 8) (bge …))
```

控制流单独一份，与块一一对应：`(flow (succ …) (fallthrough …) (root? …))`；
`(struct program (blocks flows))` 把两份装在一起（`L3/analyze.rkt`）。


打印出来长这样（顶层就是字段表，没有额外的标签壳）：

```racket
((blocks (block ((prog1 main)) (lwu t0 sp 8) (bge t1 t0 (prog1 done)))
         (block () (jal x0 (prog1cold cold)))
         ...)
 (flows  (flow (succ 1 3) (fallthrough 1) (root? #t))
         (flow (succ 2) (fallthrough #f) (root? #f))
         ...))
```

| 字段 | 含义 |
| --- | --- |
| 头（第一项） | 块头的所有链（一个位置多名都在这里）；放置规则只认它 |
| 其余项 | 程序：该块的 item（含块内的位置标记 label） |
| `succ` | 后继块 id |
| `fallthrough` | **物理下一条**是哪个块；`#f` 表示不以顺序方式落下去 |
| `root?` | 外部入口（程序入口 / 有 jalr 时地址被取过的块）；内部引用不算根，它在 CFG 里就是边 |

`fallthrough` 的判据是 `falls-through?`：

| 最后一条指令 | 会落到物理下一条吗 |
| --- | --- |
| 普通指令 / 分支 | 会 |
| `jal ra` / `jalr ra`（调用） | 会（返回地址 = pc+4） |
| `ecall` | 会（返回地址 = pc+4） |
| `jal x0` / `jalr x0`（ret）/ `ebreak` | 不会 |

注意调用和 `ecall` 也算「会」：它们的返回地址就是 pc+4，所以**下一条必须紧挨着**。

## 2. L5 输入

```
program : 块列表（L4 输出）
data    : 普通 item 列表 ((label ...) (bytes ...) (fill n b)
           (value 宽度 值) (align n) ...)
          本层的数据词汇只有这五个; 其余 item 一律当成**不透明的代码 item**
          (不查拼写、不查操作数: 那是编码层的事), 尺寸 4 字节, c.* 2 字节。

          同一个 data 列表也要喂给 L3(第二个参数): 数据里的
          (value 宽度 (label+ 链 加数)) 等于"链的地址被取过", 有间接跳转时它就是 root。
          L3 只拿它算 roots, 数据 item 不进块、不进 CFG。
layout  : ((segments (segment 名 kind start end align) ...)
           (place 段名 链 ...) ...)
```

代码里**没有 `section`**，也没有 `primary` / `entry`。

## 3. 放置

- **单位**：代码用块；数据用「label 游程」（数据没有控制流）。
- **place 行**：`(place 段名 链 ...)`，按**精确链**匹配块头的 label（`equal?`），不做前缀、不按 kind 自动落位。
  指向块内位置标记的链会报 `unmatched-place`（块不能拆）。
- **region**：命中的块是锚点；之后直到下一个锚点的块跟随它（没有身份的东西只能跟着有身份的前驱）。
- **顺序**：段内按源顺序（程序先、数据后），`place` 行书写顺序无关。
- **fallthrough 检查**：对每个 `fallthrough = j` 的块 i，块 j 必须是 i 在同一段里的**物理下一块**；否则 `broken-fallthrough`。L5 只报，不补；补跳转属于 L6/L7 的修复阶段（未实现）。

## 4. 段与度量

```racket
(segment prog1 code #x100000 #x100FFF 16)   ; 名 kind start end align
                                            ; kind 只有 code / data 两种
```

自检：名字唯一、`start < end`、`start` 按 `align` 对齐、区间不重叠。

段内单游标从 `start` 起，`label` 不占字节只记偏移，`(align n)` 向上补齐补 0，其余按形式表累加。
`align` 对齐的是**绝对地址** `start + cursor`，不是段内偏移：段 start 不一定被某个 item 的 `n` 整除（例如段 start 4 对齐、数据要 `align 16`），只按 cursor 算会算错。
产物里 `(offset k (align n))` 记的是**补齐前**的偏移，补齐后的偏移看下一条。
产物里每条 item 都带偏移注解 `(offset 偏移 item)`；一个段长这样（整张表在 `(segments …)` 字段里）：

```racket
(segment (name prog1) (kind code) (start #x100000) (end #x100FFF) (align 16)
  (items (offset 0 (label prog1 main))
         (offset 0 (lwu t0 sp 8))
         (offset 4 (bge t1 t0 (prog1 done)))
         (offset 8 (jal x0 (prog1cold cold))))
  (size 12))
```


| item | 字节 |
| --- | --- |
| `label` | 0 |
| `bytes` | 元素个数 |
| `fill n b` | `n`（重复次数 = 字节数） |
| `value 宽度 值` | `宽度`（值是什么由 L7 解释） |
| `align n` | 由游标算（按绝对地址 `start + cursor` 对齐） |
| `b*` | 4 |
| `branch-far` | 8 |
| `branch-indirect` | 12 |
| `jal` | 4 |
| `jump-far` | 8 |
| `la` | 8（预留，见下） |
| `li` | 4（兜底值，**待改**：应按常量上界预留） |
| `c.*` | 2 |
| 其他 | 4 |

可达距离：`b*` 4096，`c.beqz`/`c.bnez` 256，`c.j`/`c.jal` 2048，`jal`/`branch-far` 1048576，`branch-indirect`/`jump-far` 不设限（`la` 的 ±2GB 检查在 L7，由 `riscv-help` 的 `fits-auipc-pair?` 做）。

### `li` / `la` 的尺寸：L5 只预留

这两条是特殊伪指令，L5 **不解释**，只给字节数：

| 指令 | L5 给的字节 | 真正的展开 |
| --- | --- | --- |
| `(la rd 链)` | 8（`auipc+addi`） | L7：`delta = 符号地址 − item 地址`，交 `riscv-help` 的 `la-pcrel` / `load-pcrel`；delta 超出 auipc 范围时 `load-pcrel` 自带 scratch |
| `(la rd tmp 链)` | 8（同上） | 同上，但 scratch 用 `tmp`。形状与尺寸都不变，只是把隐式 scratch 变成显式，给以后的 frame / regalloc 层用 |
| `(li rd 常量)` | 应按 `li-size` 的上界预留 | L7：`expand-li`；字节数取决于常量范围 |

因为两边都只能给上界，L7 展开后必须核对实际尺寸：不等就回 L5 重排，迭代到不动点。
L5 不查 `li` / `la` 的目标与范围；写错链目前也不会报 `undefined-target`（`verify` 只看 `control-form?`，这是待改项）。

### 远形式：寄存器全部显式

远形式**不许从助记符里猜寄存器**。`jump-far` 的 link、scratch 都是操作数：

```racket
(branch-far      <cond> a  b  L)     ; 条件分支, 8B, 无 scratch
(branch-indirect <cond> a  b  L)     ; auipc+jalr 版, 12B, 空槽
(branch-indirect s <cond> a b L)     ; 已填
(jump-far        link  L)            ; 跳/调用, 8B, link = x0 时空槽
(jump-far        link  s  L)         ; 已填
;; <cond> ∈ beq bne blt bge bltu bgeu —— 反向分支要知道反哪个条件
```

- **远形式必须带 `<cond>`**：`(branch-far beq a b L)` 才能展开成
  `bne a b +8` + `jal x0 L`；不带条件的形式根本展不开（这是 2024 修正）。
- **没有 `call-far`**：它就是 `(jump-far ra L)`。两个名字表达同一条指令，就是在制造
  "两个合法拼写"——L5 和 L3 都必须靠 link 判断"落不落下"，所以 link 必须显式。
- `branch-indirect` 没有 link：条件分支不写链接寄存器。
- 有 link 之后 L3 才能回答 `jump-register` / `falls-through?` / `unconditional-jump?`，
  于是 L4 的"删掉跳到紧邻下一块的转移"也能作用到远形式。

### scratch: 两种槽, 不要混

| 形式 | 缺省表示 | 报 `scratch-hole` 吗 |
| --- | --- | --- |
| `(branch-indirect <cond> a b L)` | 远分支的 base 还没给 | 会（留给 L6 填） |
| `(jump-far x0 L)` / `(jump-far zero L)` / `(jump-far 0 L)` | link 是零寄存器，auipc 没有落点 | 会（留给 L6 填） |
| `(jump-far ra L)` | link 自己就是 base，**本来就不需要** scratch | 不会 |
| `(la rd 链)` | 短形式不需要 scratch，远形式由 L7 自己挑 | 不会（缺省不是缺陷） |
| `(la rd tmp 链)` | scratch 已指定 | 不会 |

所以 `scratch-hole?` 必须**读操作数**：要不要 scratch 是 link / 形式的函数，
不是"比满长度少一项"的函数。`jump-far` 的 link 判定用 `L3/insn.rkt` 的
`zero-register?`（`x0` / `zero` / `0` 都算），不在 L5 里重新维护一份拼写表。

`la` 的 scratch 是**可选槽**，所以它不进 `scratch-hole?`（`L5/forms.rkt` 的
`la-form?` / `la-scratch`）：否则程序里每个 `la` 都会报一条空槽。

相关查询：`jump-far-form?` / `jump-far-link` / `jump-far-scratch` / `la-form?` / `la-scratch`。

## 5. 校验（只记 problems，不抛异常）

```racket
((unplaced-block 0 ((main)))                 ; 块没有锚点
 (unplaced (data1 table))                    ; 数据游程没有锚点
 (unlabeled-run ((bytes 1)))                 ; 数据开头没有 label
 (ambiguous-placement (main) a b)            ; 两行 place 抢同一个链
 (unknown-segment nope)                      ; place 指向未声明的段
 (broken-fallthrough 0 1 ((a)) ((b)))        ; 顺序执行被段/区段剪断
 (code-data-mixed prog1 4 (bytes 1 2))       ; 数据落进 code 段
 (data-code-mixed data1 0 (addi a0 a0 1))    ; 指令落进 data 段
 (segment-overflow prog1 8 7)
 (segment-misaligned prog1 #x1002 16)
 (segment-overlap a b)
 (segment-name-duplicated (a b a))
 (segment-bad-range b)
 (undefined-target s1 0 (jal x0 (ghost)))
 (undefined-target d 0 (value 8 (label+ (ghost) 0)))    ; 数据里的地址字
 (value-out-of-range d 0 (value 4 (label+ (d t) 0)) #x100000000)  ; L5 才有的范围
 (needs-far prog1 8 (jal x0 (prog1cold cold)) 2097144 (code 1 0))  ; 留给 L6
 (scratch-hole prog1 0 (branch-indirect beq a0 a1 (done)) (code 0 0))  ; 留给 L6
 (scratch-hole prog1 0 (jump-far x0 (done)) (code 0 0)))  ; link=x0 才需要 base
```

最后两类不是错误，是远跳转层（L6）的入口。

**不在这个名单里的都不该是本层的事**：拼写、操作数个数、立即数范围、code 段的对齐是否
合法，都是"变二进制"那一步（L7）自己的检查。L5 只判自己模型里的东西：段、偏移、距离、放置、
符号表。

`value-out-of-range` 属于本层：判断"地址能不能放进宽度个字节"要有符号表，只有 L5 有；
它和 `needs-far` 是同一类（范围），不是指令合法性。整数的值域由 D1 查（它看得到宽度和字面量）。

## 6. 分支松弛层（L6，已做）

编号以 `ARCHITECTURE.md` 为准：松弛是 **L6**（`L6/relax.rkt`），encode 是 **L7**。

- 契约：`program + data + layout 输入 -> layout`。**不是** `layout -> layout`：
  L5 的产物已经排好偏移、没有块结构，改完没法重排，所以 L6 驱动 L5。
- 本层只做一件事：把 `needs-far` 的 item 换成大一号的形式。
- 提升阶梯：`c.*` → 普通 → `branch-far` → `branch-indirect`；`jal` → `jump-far`。
  每一步都重跑 L5；**只升不降**，所以一定收敛（单调性，见 `L6/relax.rkt` 的头注释）。
- 本层不造 label、不拆块、不改 CFG：远形式是定长 item，L7 才展开成
  "反向条件分支 + 紧接着的跳转"（与 gas `md_convert_frag_branch` 同形）。
- **空槽（scratch 寄存器）不归本层**：那是「动态内存布局 / 寄存器使用」的一部分（未实现）。
  升到 `branch-indirect` / `(jump-far x0 …)` 时会产生一个新的 `scratch-hole`，本层原样留着，
  作为和那一层的交接点。
- 补 fallthrough 跳转、trampoline、块重排不属于本层当前实现。

## 7. 与真实工具链一致的地方

- 条件分支远形式 = **反向分支 + `jal`**（8 字节，无 scratch），与 gas `md_convert_frag_branch`、LLVM `expandLongCondBr` 一致。
- 超过 ±1MB 才需要 scratch（`auipc + jalr`）；GAS 交给链接器报错，LLVM 在 machine 层用 `insertIndirectBranch` + reg scavenger。我们留给 L6，用显式空槽替代 scavenger。
- 顺序执行跨段 = 必须显式跳转；真实工具链里由 `.section`/链接脚本决定，报错方式就是「这里断了」。我们用 `broken-fallthrough` 显式化。
