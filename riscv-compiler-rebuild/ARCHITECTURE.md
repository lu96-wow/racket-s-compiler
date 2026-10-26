# 分层与接口一览

```
source(多输入)                 每层都是纯函数, 可单独测
──────────────
program list ┐
data    list ├─ L1 展平 ─→ L2 替换 ─→ L3 分析 ─→ L4 死代码消除 ─→ L5 布局 ─→ [L6 far] ─→ [L7 编码]
layout  list ┘                       (block list)  (block list)     (layout)     (预留)      (未做)
```

L3 只**分析**（s-exp → block list），L4 才开始**改**（block list → block list，会改控制流）。

## 1. 关键 API

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
| `rewrite-all` | item 列表 / 单条 item | 同形 |
| `rewrite-item` / `rewrite-one` | 单条 item | 单条 item / `#f`(未命中) |
| `make-table` / `validate-rows!` | 行表 | `table` / void |
| `pseudo-leftover?` / `fully-rewritten?` | item 列表 / 单条 | 布尔 |

数据：`rewrite-rows` `default-table` `pseudo-names` `rules` `rules-for` `pseudo-name?` `directive-heads` `reserved-heads`。

### L3 `L3/insn.rkt` `L3/cfg.rkt` `L3/analyze.rkt` — 控制流分析（不改程序）

| API | 输入 | 输出 |
| --- | --- | --- |
| `analyze` | `(listof item)` | **`(listof block)`** |
| `blocks->sexp` / `sexp->blocks` | 块列表 / 字面量 | 字面量 / 块列表 |
| `program-items` | 任意输入 | `(listof item)`（剥旧壳） |
| `build-cfg` | `(listof item)` | `graph`（CFG 内部用） |
| `cfg-reachable` | `graph` `roots` | `(listof 块 id)` |
| `cfg->lines` | `graph` | `(listof string)`（给人看） |
| `referenced-labels` | `(listof item)` | `(listof path)` |
| `address-taken-paths` | `(listof item)` | `(listof path)` |
| 分类：`branch-instruction?` `jump-instruction?` `indirect-instruction?` `trap-instruction?` `ends-block?` `falls-through?` `unconditional-jump?` `jump-target` `jump-register` `zero-register?` | 单条 item | 布尔 / 值 |
| 形状：`label-form?` `label-path` `name?` `path?` `normalize-path` | 任意 | 布尔 / 值 |

`block` 是 struct：`(struct block (id labels insns succ fallthrough root?) #:transparent)`。
`root?` 由分析层算好（入口 / 被外部引用 / 地址被取过），后面的层不用再懂指令语义。

### L4 `L4/dce.rkt` — 死代码消除（改控制流）

| API | 输入 | 输出 |
| --- | --- | --- |
| `eliminate-dead` | `(listof block)` | `(listof block)` |
| `optimize-blocks` | 同上（跑 pass 到不动点） | 同上 |
| `passes` / `pass-names` | — | `(drop-unreachable drop-transfers-to-next-block)` |

两个 pass 都会改 `succ` / `fallthrough`：删块后重新编号并重映射；删转移后该块只剩顺序边。

### L5 `L5/forms.rkt` `L5/layout.rkt` — 布局计算

| API | 输入 | 输出 |
| --- | --- | --- |
| `layout-program` | `(listof block)` + 数据 items + layout 输入 | `(layout ...)` |
| `layout-problems` | `(layout ...)` | `(listof problem)` |
| `items-of` | 任意输入 | `(listof item)` |
| 形式表：`item-size` `item-kind` `form-range` `scratch-hole?` | 单条 item | 字节数 / 类别 / 距离 / 布尔 |
| 分类：`control-form?` `control-target` `branch-form?` `jump-form?` `indirect-form?` `label-form?` `align-form?` `bytes-form?` | 单条 item | 布尔 / 值 |

### L6 `far`（预留）、L7 `encode`（未做）

- far：`(layout ...)` → `(listof block)`（升级远形式、保留/填 scratch 空槽）
- encode：`(layout ...)` → `(build ...)`

## 2. IO 形状

| 形状 | 例子 |
| --- | --- |
| 程序/数据（扁平 item） | `((label prog1 main) (lwu t0 sp 8) (bge t1 t0 (prog1 done)))` |
| 块（struct，打印） | `(block (id 0) (labels (prog1 main)) (insns (lwu …) (bge …)) (succ 1 3) (fallthrough 1) (root? #t))` |
| layout 输入 | `((segments (segment prog1 code #x100000 #x100FFF 16) …) (place prog1 (prog1 main) …))` |
| layout 产物 | `(layout (segment (name prog1) … (items (offset 0 (lwu …)) …) (size 28)) (symbols …) (problems …))` |
| build（L7） | `(build (segment (name prog1) (start …) (size …) (bytes #vu8…)) …)` |

`(quote ...)` / `(begin ...)` 是旧壳，各层入口宽容接受，出口一律 plain list。

## 3. 每个 s-expression 归谁管

| 形式 | 出现在 | 语义由谁定义 | 谁产生 | 谁消费 |
| --- | --- | --- | --- | --- |
| `(module 名 item...)` | 源 | **L1**（展平后消失） | 人 | L1 |
| `(label 链...)` | 源 → L1/L2/L3 | **L1** 定链；**L3** 定块头；**L5** 定偏移 | L1/L3/L5 | 全部 |
| `(quote ...)` / `(begin ...)` | 源 | 无（旧壳） | 人 | L1/L2/L3/L5 入口 |
| 伪指令 `(load-32 …)` `(l8 …)` `(move …)` `(ble …)` | 源 → L2 前 | **L2** 的表 | 人 | L2 |
| 真指令 `(lwu …)` `(bge …)` `(jal …)` `(jalr …)` | L2 起 | **L2** 产出；**L3** 分类；**L5** 定尺寸 | L2 | L3 / L5 |
| 远形式 `branch-far` `branch-indirect` `jump-far` `call-far` | 源或 L6 | **L5/forms**（尺寸·距离·scratch 槽） | 人 / L6 | L3 / L5 |
| `(la rd 链)` | 源 | **L5/forms** 8 字节；L7 编码 | 人 | L5 |
| `(bytes …)` `(align n)` | 数据输入 | **L5**（尺寸 / padding / kind） | 人 | L5 |
| block（struct） | L3 → L5 | **L3** | L3 | L4 / L5 |
| `(segments …)` `(place …)` | layout 输入 | **L5** | 人 | L5 |
| `(offset n item)` | L5 产物 | **L5** | L5 | L7 |
| `(layout …)` | L5 产物 | **L5** | L5 | L6 / L7 / 人 |
| `(build …)` | L7 产物 | **L7** | L7 | 加载器 |

## 4. 哪些过程用到哪些层

| 过程 | 用到的层 |
| --- | --- |
| 单文件汇编 | L1（可省）→ L2 → L3 → L4 → L5 |
| 多模块 / 多文件 | **L1 必用**（作用域前缀 + 跨输入名字表） |
| 扩伪指令 | L2（加一行表） |
| 控制流分析/调图 | L3（`analyze` + `cfg->lines`） |
| 死代码消除 | L4（`passes` 表） |
| 分段 / 地址布局 | L5（写 `segments` + `place`） |
| 远跳转 | L6（预留，消费 `needs-far` / `scratch-hole`） |
| 产物 | L7（未做） |
| 单层测试 | 每层（纯函数；L3 起 IR 是 block list） |

## 5. demo 的约定

每个 `L*/demo.rkt` 只出现**该层自己的输入输出**：

| demo | 输入 | 输出 |
| --- | --- | --- |
| `L1/demo.rkt` | `(module ...)` 源 | 扁平 item + 名字表 |
| `L2/demo.rkt` | 扁平 item（含伪指令） | 扁平 item |
| `L3/demo.rkt` | 扁平 item | block list |
| `L4/demo.rkt` | block list（用 `sexp->blocks` 写字面量） | block list |
| `L5/demo.rkt` | block list + 数据 item + layout 输入 | `(layout ...)` |

层与层之间不互相调用；要看整条链就按顺序手动串。

## 6. 三张"数据表"

| 表 | 位置 | 管什么 |
| --- | --- | --- |
| 替换表 | `L2/table-base.rkt` … `L2/table.rkt` | 伪指令 → 真指令 |
| 指令分类表 | `L3/insn.rkt` | 分支 / 跳转 / 间接 / 陷阱 / 是否顺序落下 |
| 形式表 | `L5/forms.rkt` | 字节数 / 可达距离 / 是否需要 scratch |
