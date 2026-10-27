# 分层与接口一览

```
      rich 数据 ─→ D1 数据定义 ─┐
                                │
source(多输入)                  │ 每层都是纯函数, 可单独测
──────────────                  │
program list ┐                  ↓
data    list ├─ L1 展平 ─→ L2 替换 ─→ L3 分析 ─→ L4 死代码消除 ─→ L5 布局 ─→ L6 松弛 ─→ [L7 编码]
layout  list ┘                      program       program         (layout)     (layout)     (未做)
```

D1 把 rich 数据（`b8`/`b16`/`b64`/`bN-array`/`utf-string`）落成**核心 item**：
`label` / `bytes` / `fill` / `value` / `align`。**端序不归 D1**：`value` 只带"宽度 + 值"，
字节序在 L7 落字节时才定（端序在整个流水线里只出现这一次）。

L3 只**分析**（s-exp → block list），L4 才开始**改**（block list → block list，会改控制流）。

## 0. 词汇边界（每层只关心自己）

每层只处理**与自己设计的那几种 s-exp** 相关的逻辑，其余一律是**不透明载荷**：

| 层 | 自己认识的 item | 其余 |
| --- | --- | --- |
| D1 | rich 数据（宽度/数组/字符串/对齐/label） | 不认识就 `error`（它是入口） |
| L1 / L2 | `module`、`label` 链、替换表里的伪指令名 | 透传 |
| L3 / L4 | 控制流助记符、`label`、块/流结构 | 普通指令：不透明 |
| L5 | 数据 `label` / `bytes` / `fill` / `value` / `align`；控制形式的目标位与尺寸 | **不透明代码：4 字节**（`c.*` 2 字节） |

推论（也是本仓的硬规矩）：

- **真实指令是否合法不归 L1–L5 管**：拼写、操作数个数、立即数范围、code 段对齐是否合法，
  都是「变二进制」（L7）那一步的事。中间层不写这类检查。
- 因此 L5 的 `item-size` / `item-kind` 兜底（`4` 字节 / `'code`）**是设计，不是漏检**。
- 反过来，谁**输出**了别人的词汇就是 bug：D1 不输出 `b16` 这种"宽度 + 值"的组合名，
  它输出 `(value 宽度 值)` —— 宽度是**数据**，所以 L5 不需要认识任何宽度名。
- 数据不是只给 L5：D1 的输出**同时**喂给 L3（只用来找"地址被取过"的链，
  即 `(value 宽度 (label+ 链 加数))`），否则函数指针表里的函数会被 L4 当死代码删掉。
- 一个名字只能有一个归属：`fill` 归 L5（padding 需要它），D1 只是它的生产者。

`li` / `la` 是**特殊伪指令**，不进 L2 的替换表，源样一路透传到 L7：
它们要「最终地址」才能展开（`la` 要 delta、`li` 要常量），所以在 L5 之后由 L7
调用 `../riscv-help` 展开；L5 只为它们预留字节。

## 1. 关键 API

### D1 `D1/expand.rkt` — 数据定义（rich 数据 → 核心 item）

| API | 输入 | 输出 |
| --- | --- | --- |
| `expand-data` | rich 数据 item 列表 | `(listof core item)`（`label` / `bytes` / `fill` / `value` / `align`） |
| `expand-item` | 单条 item | `(listof core item)` |
| `program-items` | 任意输入 | `(listof item)`（剥旧壳） |
| 查询：`fill-form?` `width-form?` `width-of` | 单条 item | 布尔 / 宽度 |

宽度、值域、字符串编码、数组压缩都在这层定；**端序不在这层**（L7 落字节时才定）。
`value` 的值可以是整数，也可以是地址字 `(label+ 链 加数)` —— 地址值要等 L5 算完符号表、
L7 落字节时才定，和代码侧的 `la` / `li` 是同一类"值推后"的 item。

### L1 `L1/flatten.rkt` — 模块展平 + 链式查表

| API | 输入 | 输出 |
| --- | --- | --- |
| `flatten-inputs` | `(listof (listof item))` 多输入 | `(values (listof (listof item)) 名字表)` |
| `flatten-program` | `(listof item)` | `(listof item)` |
| `flatten-items` | `(listof item)` | `(values (listof item) 名字表)` |
| `name?` / `path?` | 任意 | 布尔 |

多输入共享一张名字表，所以程序里能引用数据里的 label。

### L2 `L2/rewrite.rkt` — 按表替换（+ `table.rkt` / `table-*.rkt` 数据）

| API | 输入 | 输出 |
| --- | --- | --- |
| `rewrite-program` | `(listof item)` `[table]` | `(listof item)` |
| `rewrite-tree` | item 列表 / 单条 item / 原子 | 同形 |
| `expand-item` | 单条 item | 单条 item（展开到不再命中） |
| `apply-rule` | 单条 item | 单条 item / `#f`（未命中；只跑一次规则） |
| `make-table` / `check-rows` | 行表 | `table` / void |
| `pseudo-leftover?` / `fully-rewritten?` | item 列表 / 单条 | 布尔 |

数据：`rewrite-rows` `default-table` `rules` `rules-for` `pseudo-name?` `directive-heads` `reserved-heads`。

### L3 `L3/insn.rkt` `L3/cfg.rkt` `L3/analyze.rkt` — 控制流分析（不改程序）

| API | 输入 | 输出 |
| --- | --- | --- |
| `analyze` | `(listof item)` + 可选 data items | **`program`**（blocks + flows）；data 只贡献 roots |
| `block-head` / `block-items` | 块 | 头 label 链列表 / 程序 item |
| `flow-succ` / `flow-fallthrough` / `flow-root?` | flow | 值 |
| `program->sexp` / `sexp->program` | program / 字面量 | 字面量 / program |
| `program-items` | 任意输入 | `(listof item)`（剥旧壳） |
| `build-cfg` | `(listof item)` | `graph`（CFG 内部用） |
| `cfg-reachable` | `graph` `roots` | `(listof 块 id)` |
| `cfg->lines` | `graph` | `(listof string)`（给人看） |
| `referenced-labels` | `(listof item)` | `(listof path)` |
| `address-taken-paths` | `(listof item)` | `(listof path)`（含 `(value w (label+ 链 加数))` 里的链） |
| 分类：`branch-instruction?` `jump-instruction?` `indirect-instruction?` `trap-instruction?` `ends-block?` `falls-through?` `unconditional-jump?` `jump-target` `jump-register` `zero-register?` | 单条 item | 布尔 / 值 |
| 形状：`label-form?` `label-path` `name?` `path?` `normalize-path` | 任意 | 布尔 / 值 |

块是**两部分**的 s-exp：身份 + 程序。

```racket
(block <头 label 链列表> item ...)     ; 例: (block ((prog1 main)) (lwu t0 sp 8) (bge …))
```

只想要"程序"的层直接 `(cddr block)` 即可，不需要认识块的其他信息。

**块边界只由控制流决定**：程序开头 / 控制转移的目标 label / 切流指令之后。
非目标的 `label` 不是边界，它作为位置标记留在块的程序里。

控制流信息**不在块里**，单独一份、与块一一对应：

```racket
(flow (succ <块下标> ...) (fallthrough <块下标>|#f) (root? <bool>))
```

`root?` = 外部入口：程序入口，或（有 `jalr` 时）地址被取过的块。
内部引用不算根——它们在 CFG 里就是边，这样死代码才删得干净。

两份数据装在一起：`(struct program (blocks flows))`（`L3/analyze.rkt`）。

### L4 `L4/dce.rkt` — 死代码消除（改控制流）

| API | 输入 | 输出 |
| --- | --- | --- |
| `eliminate-dead` | `program` | `program` |
| `optimize-program` | 同上（跑 pass 到不动点） | 同上 |
| `passes` / `pass-names` | — | `(drop-unreachable drop-transfers-to-next-block merge-empty-blocks)` |

三个 pass 都会改 `succ` / `fallthrough`：

- `drop-unreachable`：删从 `root?` 走不到的块，重新编号并重映射
- `drop-transfers-to-next-block`：删掉跳到紧邻下一块的转移，该块只剩顺序边
- `merge-empty-blocks`：空块的 label 与下一块同址，并进下一块（末尾空块保留）

### L5 `L5/forms.rkt` `L5/layout.rkt` — 布局计算

| API | 输入 | 输出 |
| --- | --- | --- |
| `layout-program` | `program` + 数据 items + layout 输入 | `((segments …) (symbols …) (problems …))` |
| `layout-problems` | layout 产物 | `(listof problem)` |
| `program-items` | 任意输入 | `(listof item)`（剥旧壳） |
| 形式表：`item-size` `item-kind` `form-range` `scratch-hole?` | 单条 item | 字节数 / 类别 / 距离**区间** `(lo . hi)` / 布尔 |
| 分类：`control-form?` `control-target` `branch-form?` `jump-form?` `indirect-form?` `label-form?` `align-form?` `bytes-form?` `fill-form?` `value-form?` `label-expr?` `compressed-form?` | 单条 item | 布尔 / 值 |
| 地址字：`value-width` `value-payload` `label-expr-chain` `label-expr-addend` | 单条 item | 宽度 / 值 / 链 / 加数 |
| 显式寄存器：`jump-far-form?` `jump-far-link` `jump-far-scratch` `la-form?` `la-scratch` | 单条 item | 布尔 / 寄存器 |

### L6 `L6/relax.rkt` — 分支松弛（已做）

| API | 输入 | 输出 |
| --- | --- | --- |
| `relax` | `program` + data + layout 输入 | `layout`（`needs-far` 已经销完；`scratch-hole` 原样留着） |
| `far-step` | 单条 item | 大一号的形式 / `#f`（到头了） |

**契约改成 `program + data + layout -> layout`**：L5 的产物已经排好偏移、没有块结构，
改完没法重排，所以 L6 **驱动** L5，而不是吃 L5 的产物（`layout -> layout` 做不到）。

提升阶梯（语义不变、尺寸只增）：`c.*` → 普通 → 远形式 → 间接远形式；`jal` → `jump-far`。
每次都重跑 L5。收敛性来自单调性：**任何一圈都只会让 item 变长，而两个端点之间跨过变长点
的距离只会变大**，所以"太远"的集合单调递增，每个 item 最多升 3 档。

本层**不造 label、不拆块、不改 CFG**：远形式是定长 item，由 L7 展开成"反向条件分支 +
紧接着的跳转"（与 gas `md_convert_frag_branch` 同形）。所以 `place` 行永远有效，
`fallthrough` 也不会因为松弛而断。

**空槽不填**：`(branch-indirect <cond> a b L)` / `(jump-far x0 L)` 需要临时寄存器，
那属于「动态内存布局 / 寄存器使用」那一层（**未实现**），本层只把它留在
`scratch-hole` problem 里当交接点。升到这两档就会产生新的空槽，然后循环停下。

### L7 `encode`（未做）

L7 还没建目录，先把契约写死在这里（编号以本文为准）。

| 层 | 输入 | 输出 | 职责 |
| --- | --- | --- | --- |
| L6 relax | `program` + data + layout 输入 | layout | 消费 `needs-far`：超范围 item 升成远形式；自己驱动 L5 重排到不动点（**空槽不填**） |
| L7 encode | layout | `(build ...)` | `li`/`la` 展开（riscv-help）、远形式展开、指令编码、立即数范围检查、**`(value w …)` 落字节（端序在这一步定）**、`(label+ 链 加数)` 求值、有致命 problem 就拒绝出 `(build ...)` |

**为什么 `li` / `la` 在 L7 才展开**

- `(la rd 链)` 要 `delta = 符号地址 − 当前 item 地址`，两个地址都只有 L5 之后才有。
  L7 用 `la-pcrel`（已知 delta）或 `load-pcrel`（自动选近/远形式，远形式自带 scratch）。
  短形式不需要 scratch，所以 `la` 的 scratch 是**可选槽**：`(la rd 链)` 由 L7 自己挑，
  `(la rd tmp 链)` 显式指定（给以后的 frame / regalloc 用）。两者尺寸相同，都不报 `scratch-hole`
  （只有 `branch-indirect` 那种**必填却缺失**的才算空槽；`jump-far` 要不要 scratch
  取决于它的 link：`(jump-far x0 L)` 缺 base 要报，`(jump-far ra L)` 自己就是 base）。
  远形式的寄存器全部显式，见 `L5/DESIGN.md`「远形式：寄存器全部显式」。
- `(li rd 常量)` 与布局无关，但它和 `la` 是同一类「一条源 item 变成多条指令」的伪指令，
  放在同一处展开；用 `expand-li`，字节数可以问 `li-size`。
- 两者的展开字节数都**不是常量**（`li` 看值的范围，`la` 看距离），所以 L5 只能按**上界预留**。
  L7 展开后若实际尺寸 ≠ 预留，必须回到 L5 重排，迭代到不动点（relaxation）。
- L2/L3/L4 只把 `li` / `la` 当普通 item 透传；L5 只量尺寸、不解释。
  谁都不许在中途把它们改成 `lui`/`addi`/`auipc`，否则 L7 的地址就算错了。

## 2. IO 形状

| 形状 | 例子 |
| --- | --- |
| 程序/数据（扁平 item） | `((label prog1 main) (lwu t0 sp 8) (bge t1 t0 (prog1 done)))` |
| 程序（块 + 流） | `((blocks (block ((prog1 main)) (lwu …) (bge …)) …) (flows (flow (succ 1 3) (fallthrough 1) (root? #t)) …))` |
| layout 输入 | `((segments (segment prog1 code #x100000 #x100FFF 16) …) (place prog1 (prog1 main) …))` |
| layout 产物 | `((segments (segment (name prog1) … (items (offset 0 (lwu …)) …) (size 28)) …) (symbols …) (problems …))` |
| build（L7） | `(build (segment (name prog1) (start …) (size …) (bytes #vu8…)) …)` |

`(quote ...)` / `(begin ...)` 是旧壳，各层入口宽容接受，出口一律 plain list。

## 3. 每个 s-expression 归谁管

| 形式 | 出现在 | 语义由谁定义 | 谁产生 | 谁消费 |
| --- | --- | --- | --- | --- |
| `(module 名 item...)` | 源 | **L1**（展平后消失） | 人 | L1 |
| `(label 链...)` | 源 → L1/L2/L3 | **L1** 定链；**L3** 定块头；**L5** 定偏移 | L1/L3/L5 | 全部 |
| `(quote ...)` / `(begin ...)` | 源 | 无（旧壳） | 人 | L1/L2/L3/L5 入口 |
| 伪指令 `(load-32 …)` `(l8 …)` `(move …)` `(ble …)` | 源 → L2 前 | **L2** 的表 | 人 | L2 |
| 真指令 `(lwu …)` `(bge …)` `(jal …)` `(jalr …)` `(c.beqz …)` `(c.j …)` | L2 起 | **L2** 产出；**L3** 分类；**L5** 定尺寸 | L2 | L3 / L5 |
| 远形式 `(branch-far <cond> a b L)` `(branch-indirect [s] <cond> a b L)` `(jump-far link [s] L)` | 源或 L6 | **L5/forms**（尺寸·距离·scratch 槽）；**L3** 分类（link 显式，`falls-through?` 可算） | 人 / L6 | L3 / L5 |
| `(li rd 常量)` | 源 → L7 | **L7**（`riscv-help` 的 `expand-li` / `li-size`） | 人 | L3 当普通指令 / L5 量尺寸 / L7 展开 |
| `(la rd 链)` / `(la rd tmp 链)` | 源 → L7 | **L7**（`riscv-help` 的 `la-pcrel` / `load-pcrel`；delta = 符号地址 − 当前地址） | 人 | L3 当普通指令 / L5 量尺寸 / L7 展开 |
| `(bytes …)` `(fill n b)` `(align n)` | D1 输出 / 数据输入 | **L5**（尺寸 / padding / kind）；`fill` 归 L5，D1 是生产者 | D1 / 人 | L5 |
| `(value 宽度 值)` | D1 输出 | **D1** 出宽度+值；**L5** 量尺寸并查地址范围；**L7** 定端序并落字节 | D1 | L3（取地址）/ L5 / L7 |
| `(label+ 链 加数)` | `value` 的值 / 源 | **D1** 归一形状；**L3** 当取地址；**L5** 解析范围；**L7** 落值 | 人 / D1 | L3 / L5 / L7 |
| rich 数据 `b8` `b16` `b64` `bN-array` `utf-string` | 源 | **D1**（宽度 / 值域 / 字符串） | 人 | D1 |
| `(block <头 label> item ...)` | L3 → L5 | **L3** | L3 | L4 / L5 |
| `(flow …)` | L3 → L5 | **L3** | L3 | L4 / L5 |
| `(segments …)` `(place …)` | layout 输入 | **L5** | 人 | L5 |
| `(offset n item)` | L5 产物 | **L5** | L5 | L7 |
| layout（字段表） | L5 产物 | **L5** | L5 | L6 / L7 / 人 |
| `(build …)` | L7 产物 | **L7** | L7 | 加载器 |

## 4. 哪些过程用到哪些层

| 过程 | 用到的层 |
| --- | --- |
| 单文件汇编 | L1（可省）→ L2 → L3 → L4 → L5 |
| 数据（必需） | D1 → L3（只算 roots）→ L5 |
| 数据里的地址字 | D1 出 `(value w (label+ 链 n))` → L5 查范围 → L7 定端序落字节 |
| 多模块 / 多文件 | **L1 必用**（作用域前缀 + 跨输入名字表） |
| 扩伪指令 | L2（加一行表） |
| 控制流分析/调图 | L3（`analyze` + `cfg->lines`） |
| 死代码消除 | L4（`passes` 表） |
| 分段 / 地址布局 | L5（写 `segments` + `place`） |
| 分支松弛 / 远跳转 | L6（`relax`；只消费 `needs-far`） |
| `li` / `la` 展开 | L7（`../riscv-help`；`la` 还要 L5 的符号表） |
| 端序 / `value` 落字节 | L7（全流水线只有这一处写端序） |
| 产物 | L7（未做） |
| 单层测试 | 每层（纯函数；L3 起 IR 是 block list） |

## 5. demo 的约定

每个 `L*/demo.rkt` 只出现**该层自己的输入输出**：

| demo | 输入 | 输出 |
| --- | --- | --- |
| `D1/demo.rkt` | rich 数据 | 核心 item（`label` / `bytes` / `fill` / `value` / `align`） |
| `L1/demo.rkt` | `(module ...)` 源 | 扁平 item + 名字表 |
| `L2/demo.rkt` | 扁平 item（含伪指令） | 扁平 item |
| `L3/demo.rkt` | 扁平 item（+ 可选 data） | block list |
| `L4/demo.rkt` | block list（用 `sexp->program` 写字面量） | block list |
| `L5/demo.rkt` | block list + 数据 item + layout 输入 | `((segments …) (symbols …) (problems …))` |
| `L6/demo.rkt` | block list + layout 输入 | 同样的 layout，但远分支已经升好形式（空槽留着） |

层与层之间不互相调用；要看整条链就按顺序手动串。

`li` / `la` 在 L2~L5 的 demo 里只代表**透传**，不代表该层有语义
（`L2/demo.rkt` 里 `(li t2 42) ; 真指令, 透传` 的注释是错的：`li` 是伪指令。代码未改，以本文为准）。

## 6. 数据表与外部展开器

| 表 | 位置 | 管什么 |
| --- | --- | --- |
| 替换表 | `L2/table-base.rkt` … `L2/table.rkt` | 伪指令 → 真指令（**不含 `li` / `la`**） |
| 指令分类表 | `L3/insn.rkt` | 分支 / 跳转 / 间接 / 陷阱 / 是否顺序落下（含 `c.*` 与远形式） |
| 形式表 | `L5/forms.rkt` | 字节数 / 类别 / 可达距离 / 是否需要 scratch / 数据值宽度 |
| 展开器（外部） | `../riscv-help`：`li` `la-pcrel` `load-pcrel` `branch-long` `jump-*` | `li` / `la` / 远分支 / 远跳转的最终展开；本仓不重复实现 |

`li` / `la` 的展开器不在本仓：它是 `riscv-help` 的公开 API（见其 `main.rkt`），
L7 只负责「把地址算好、传进去、把结果接回来」。

## 7. 已知缺口（按归属层）

| 层 | 缺什么 | 状态 |
| --- | --- | --- |
| L2 | 伪指令表只覆盖 load/store/move/nop/c.nop/4 条换位分支 | 可加行；`li` / `la` 不进表 |
| L5 | `li` 走 `item-size` 兜底 4 字节，应按常量上界预留 | 待改（形式表） |
| L5 | `(la rd 链)` 不查 `undefined-target`、不查 ±2GB（`form-range` 返回 `#f`） | 待改（`verify`） |
| L5 | `li` / `la` 预留的 4 / 8 字节是**下界**，不是上界（`li-general64` 最坏约 32B、`la` 远形式 `li-size + 8`） | 待改（尺寸契约） |
| L5 | 符号重名不报（`collect-symbols` 用 `assoc` 取第一个） | 待改 |
| L5 | 只报 `broken-fallthrough`，不补跳转 | 修复属于 L6/L7 |
| L6 | 只做"升形式"；补 `fallthrough` 跳转、trampoline、块重排没做 | 未做 |
| 空槽（scratch 寄存器） | 谁填、填哪个寄存器 = 动态内存布局 / 寄存器使用 | **留空，等待实现** |
| L6 | 跨段到冷段没有 trampoline（LLVM 那条路），一律就地升形式 | 按需 |
| L7 | 目录不存在：layout 之后没有消费者；`li`/`la` 展开、编码表、立即数范围检查都在这里 | 未做 |
| 源 | 缺 `export` / `entry`，外部入口会被 L4 当死代码删掉 | 未做 |
| 源/数据 | 数据核心词只有 `label`/`bytes`/`fill`/`value`/`align`；缺 `ascii`、`.bss`、真 reloc | 未做 |
| 链外 | 没有 driver、没有 L1→L7 的整链测试 | 未做 |

## 8. 代码约定

- **顶层不带标签**：层与层之间传的数据一律是「字段表」——
  `((blocks …) (flows …))`、`((segments …) (symbols …) (problems …))`。
  只有子结构带标签：`(block …)` `(flow …)` `(segment …)` `(offset n item)`。
- **记录写法**：身份 + 程序用位置式（`(block 头 item…)`）；可选字段用具名式
  （`(flow (succ …) (fallthrough …) (root? …))`、`(segment (name …) (kind …) …)`）。
- **命名**：谓词以 `?` 结尾；**有可观察副作用**的以 `!` 结尾（`problem!`、`flush!`），纯函数不加；
  层入口统一 `<动词>-<名词>`（`flatten-program`、`rewrite-program`、`layout-program`）。
- **「剥旧壳 + 规整成 item 列表」的函数一律叫 `program-items`**：
  L1/L2/L3/L5 各一份（每层独立，层间不共享）。
- **迭代上限**：`max-expand-steps`（L2，展开链）、`max-rounds`（L4，pass 不动点）。
- **error 标签 = 模块名**：`'flatten` `'table` `'rewrite` `'analyze` `'layout`（不用函数名）。
- **数据表集中放**：`table-*.rkt` / `insn.rkt` / `forms.rkt` 只放数据与查询，不放变换逻辑。
