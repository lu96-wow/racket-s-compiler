# 分层与接口一览

```
source(多输入)            每层都是 s-exp -> s-exp 的纯函数, 无副作用, 可单独测
──────────────
program list ┐
data    list ├─ L1 展平 ─→ L2 替换 ─→ L3 CFG ─→ L4 布局 ─→ [L5 far] ─→ [L6 编码]
layout  list ┘                (块列表)                          (预留)      (未做)
```

## 1. 关键 API

### L1 `L1/flatten.rkt` — 模块展平 + 链式查表

| API | 输入 | 输出 |
| --- | --- | --- |
| `flatten-inputs` | `(listof (listof item))` 多个输入 | `(values (listof (listof item)) 名字表)` |
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
| `make-table` | `(listof row)` `[reserved]` | `table` 结构 |
| `pseudo-leftover?` / `fully-rewritten?` | item 列表 / 单条 | 布尔 |
| `validate-rows!` | `(listof row)` | void（校验表） |

数据：`rewrite-rows` `default-table` `pseudo-names` `rules` `rules-for` `pseudo-name?` `directive-heads` `reserved-heads`。

### L3 `L3/insn.rkt` `L3/cfg.rkt` `L3/opt.rkt` — 控制流

| API | 输入 | 输出 |
| --- | --- | --- |
| `build-cfg` | `(listof item)` | `graph`（块向量 + `indirect?`） |
| `cfg-reachable` | `graph` `roots` | `(listof 块 id)` |
| `cfg->lines` | `graph` | `(listof string)`（给人看） |
| `referenced-labels` | `(listof item)` | `(listof path)` |
| `address-taken-paths` | `(listof item)` | `(listof path)` |
| `optimize-program` | `(listof item)` | **`(listof block)`** |
| `optimize-items` | `(listof item)` `ctx` | `(listof item)` |
| `make-context` / `passes` / `pass-names` | — | 上下文 / 规则表 / 名字 |
| 分类：`branch-instruction?` `jump-instruction?` `indirect-instruction?` `trap-instruction?` `ends-block?` `falls-through?` `unconditional-jump?` `jump-target` `jump-register` `zero-register?` | 单条 item | 布尔 / 值 |
| 形状：`label-form?` `label-path` `name?` `path?` `normalize-path` | 任意 | 布尔 / 值 |

### L4 `L4/forms.rkt` `L4/layout.rkt` — 布局计算

| API | 输入 | 输出 |
| --- | --- | --- |
| `layout-program` | `(listof block)` + `(listof item)`(数据) + layout 输入 | `(layout ...)` |
| `layout-problems` | `(layout ...)` | `(listof problem)` |
| `items-of` | 任意输入 | `(listof item)`（剥旧壳） |
| 形式表：`item-size` `item-kind` `form-range` `scratch-hole?` | 单条 item | 字节数 / 类别 / 距离 / 布尔 |
| 分类：`control-form?` `control-target` `branch-form?` `jump-form?` `indirect-form?` `label-form?` `align-form?` `bytes-form?` | 单条 item | 布尔 / 值 |
| 段：`segment-form?` `segment-kind?` | 任意 | 布尔 |

### L5 `far`（预留，不实现）

契约：`(layout ...)` → `(listof block)`（升级远形式、保留/填 scratch 空槽）。L4 只负责报 `needs-far` / `scratch-hole`。

### L6 `encode`（未做）

契约：`(layout ...)` → `(build ...)`（形式 → 字节，`offset` 注解 → 偏移）。

## 2. IO 形状

### 2.1 程序 / 数据（扁平 item 列表）

```racket
'((label prog1 main) (lwu t0 sp 8) (bge t1 t0 (prog1 done)) ...)
'((label data1 table) (bytes 1 2 3 4) (align 8) ...)
```

- item = 一个列表；`label` 的 cdr 是**链**（多个名字就是块头多条 label）
- `(quote ...)` / `(begin ...)` 是旧壳，入口宽容接受，出口一律 plain list

### 2.2 L3 块列表

```racket
((block (id 0) (labels ((prog1 main))) (insns ((lwu t0 sp 8) (bge t1 t0 (prog1 done))))
        (succ (1 3)) (fallthrough 1))
 (block (id 1) (labels ()) (insns ((jal x0 (prog1cold cold)))) (succ (2)) (fallthrough #f)))
```

### 2.3 layout 输入

```racket
((segments (segment prog1     code #x100000 #x100FFF 16)
           (segment prog1cold code #x300000 #x300FFF 16)
           (segment data1     data #x001000 #x0010FF 16))
 (place prog1     (prog1 main) (prog1 done))
 (place prog1cold (prog1cold cold))
 (place data1     (data1 table)))
```

### 2.4 layout 产物

```racket
(layout
  (segment (name prog1) (kind code) (start #x100000) (end #x100FFF) (align 16)
    (items (offset 0 (label prog1 main)) (offset 0 (lwu t0 sp 8)) ...)
    (size 28))
  ...
  (symbols (((prog1 main) prog1 0 #x100000) ...))
  (problems ((needs-far prog1 8 (jal x0 (prog1cold cold)) 2097144))))
```

## 3. 每个 s-expression 归谁管

| 形式 | 出现在 | 语义由谁定义 | 谁产生 | 谁消费 |
| --- | --- | --- | --- | --- |
| `(module 名 item...)` | 源 | **L1**（作用域前缀，展平后消失） | 人 | L1 |
| `(label 链...)` | 源 → L1/L2/L3/L4 | **L1** 定链；**L3** 定"块头"；**L4** 定偏移 | L1/L3/L4 | 全部 |
| `(quote ...)` / `(begin ...)` | 源 | 无（旧壳，宽容接受） | 人 | L1/L2/L3/L4 入口 |
| `(section 名)` | — | **已删除**（段归属在 layout 的 place 行） | — | — |
| 伪指令 `(load-32 …)` `(l8 …)` `(move …)` `(ble …)` … | 源 → L2 前 | **L2** 的表 | 人 | L1 当普通 item；L2 展开；L3 不再见 |
| 真指令 `(lwu …)` `(sd …)` `(add …)` `(bge …)` `(jal …)` `(jalr …)` `(ecall)` `(ebreak)` | L2 输出及以后 | **L2** 产出；**L3** 分类（分支/跳转/陷阱/顺序）；**L4** 定尺寸 | L2 | L3 / L4 |
| 远形式 `branch-far` `branch-indirect` `jump-far` `call-far` | 源（手写）或未来 L5 | **L4/forms** 定尺寸、距离、scratch 空槽；**L5** 未来产出 | 人 / L5 | L3（当分支/跳转）/ L4 |
| `(la rd 链)` | 源 | **L4/forms** 定 8 字节；**L6** 未来编码 | 人 | L4 |
| `(bytes n...)` | 数据输入 | **L4/forms** 定尺寸=长度；**L4** 判 kind | 人 | L4 |
| `(align n)` | 数据/代码 | **L4** 算 padding（代码段要求 4 的倍数） | 人 | L4 |
| `(block (id …) (labels …) (insns …) (succ …) (fallthrough …))` | L3 输出 | **L3** | L3 | L4 |
| `(segments (segment 名 kind start end align) …)` | layout 输入 | **L4** | 人 | L4 |
| `(place 段名 链 …)` | layout 输入 | **L4**（精确匹配 + region） | 人 | L4 |
| `(offset 偏移 item)` | L4 产物 | **L4** | L4 | L6（编码） |
| `(layout (segment …) (symbols …) (problems …))` | L4 产物 | **L4** | L4 | L5 / L6 / 人 |
| `(build …)` | L6 产物（未做） | **L6** | L6 | 加载器 |

## 4. 哪些过程用到哪些层

| 过程 | 用到的层 | 说明 |
| --- | --- | --- |
| 单文件汇编 | L1（可省）→ L2 → L3 → L4 | 没有 module 时 L1 是恒等 |
| 多模块 / 多文件 | **L1 必用** | 展平作用域名 + 跨输入共享名字表 |
| 扩伪指令 | L2 | 加一行表（名字 + 操作数模式 → 展开） |
| 控制流优化 | L3 | 加 pass（表驱动，可选） |
| 分段/地址布局 | L4 | 写 `segments` + `place` |
| 远跳转处理 | L5（预留） | 消费 `needs-far` / `scratch-hole` |
| 生成产物 | L6（未做） | `layout` → `build` |
| 调试图 | L3 `cfg->lines`、L4 `layout-problems`、L2 `pseudo-leftover?` | 每层都能单独看 |
| 单层测试 | 每层 | 全部 `s-exp → s-exp`，无副作用 |

## 5. demo 的约定

每个 `L*/demo.rkt` 只出现**该层自己的输入输出**：

| demo | 输入 | 输出 |
| --- | --- | --- |
| `L1/demo.rkt` | `(module ...)` 源 | 扁平 item + 名字表 |
| `L2/demo.rkt` | 扁平 item（含伪指令） | 扁平 item |
| `L3/demo.rkt` | 扁平 item（L2 输出，无 module） | 块列表 |
| `L4/demo.rkt` | 块列表 + 数据 item + layout 输入 | `(layout ...)` |

层与层之间不互相调用；要看整条链就按顺序手动串（或用测试里的 pipeline 用例）。

## 6. 三张"数据表"

| 表 | 位置 | 管什么 |
| --- | --- | --- |
| 替换表 | `L2/table-base.rkt` … `L2/table.rkt` | 伪指令 → 真指令 |
| 指令分类表 | `L3/insn.rkt` | 分支 / 跳转 / 间接 / 陷阱 / 是否顺序落下 |
| 形式表 | `L4/forms.rkt` | 字节数 / 可达距离 / 是否需要 scratch |
