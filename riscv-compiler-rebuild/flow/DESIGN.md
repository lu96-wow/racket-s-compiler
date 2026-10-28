# flow 构建流（`flow/flow.rkt`）

> 速览（功能 / s-exp / 设计理由）：[`../SEXP.md#flow`](../SEXP.md#flow)。
>
> 用一张 stage 表 + **选择器**决定跑哪些层：可以写单层、层组，也可以写任意片段。
> `flow` 本身不做编译，只按顺序调用各层并维护“在途值”。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| 把层名/层组/片段展开成扁平层名列表 | 任何实际的编译逻辑（都在各层里） |
| 按列表顺序跑 stage | 自动挑选层 / 自动排序 |
| 每步检查依赖（`requires` 在不在） | 判断某个层该不该跑（那是选择器的事） |
| 维护“在途值”（名字 → 值） | 改各层的契约 |
| 依赖缺了说清“谁能提供” | 保存跨调用的全局状态 |

## 2. 选择器

```racket
(run-flow target 'analyze seeds)                      ; 单层
(run-flow target 'frontend seeds)                     ; 层组
(run-flow target '(frontend ir backend) seeds)        ; 多个层/组，按顺序展开
(run-flow target '((expand-data flatten) (analyze dce)) seeds) ; 任意片段
```

`select-stages` 把选择器展开成扁平层名列表；列表里的层仍然按顺序执行，
所以“层组/片段”只是写法，没有额外语义。

**预定义层组**

| 组名 | 展开 | 用途 |
| --- | --- | --- |
| `frontend` | `expand-data flatten expand-pseudo` | 从 rich 数据/源码走到真指令 item |
| `ir` | `analyze dce` | 控制流分析 + 死代码消除 |
| `backend` | `relax encode` | 松弛 + 编码（layout 在 relax 内部跑） |
| `all` | `default-flow` | 默认全流程 |

组名不能和层名重名；组里只写层名。想临时组合就直接写列表，不必先定义组。

## 3. 输入 / 输出

```racket
(run-flow target selector seeds)
;; -> context (hash)，用 (flow-value ctx 'build) 取出产物
```

`seeds` 有两种写法：

```racket
;; 1) 显式 seed 表
'((rich-data . …)
  (program-items . …)
  (layout-spec . …))

;; 2) 上一趟 run-flow 的 context 直接当下一次输入（片段测试）
(run-flow target 'ir (run-flow target 'frontend seeds))
```

**在途值（名字就是契约）**

| 名字 | 是什么 | 谁产 |
| --- | --- | --- |
| `rich-data` | 人写的 rich 数据（seed） | — |
| `data-items` | 核心数据 item | `expand-data` / `flatten` / seed |
| `program-items` | 扁平程序 item（可含 `(module …)`） | seed / `flatten` / `expand-pseudo` |
| `names` | `flatten` 建的名字表 | `flatten` |
| `program` | `(struct program blocks flows)` | `analyze` / `dce` |
| `layout` | 布局产物 | `layout` / `relax` |
| `build` | 最终产物 `(build …)` | `encode` |

**stage 表（顺序无关，跑的顺序只看选择器）**

| stage | requires | provides |
| --- | --- | --- |
| `expand-data` | `rich-data` | `data-items` |
| `flatten` | `program-items` `data-items` | `program-items` `data-items` `names` |
| `expand-pseudo` | `program-items` | `program-items` |
| `analyze` | `program-items` `data-items` | `program` |
| `dce` | `program` | `program` |
| `layout` | `program` `data-items` `layout-spec` | `layout` |
| `relax` | `program` `data-items` `layout-spec` | `layout` |
| `encode` | `layout` | `build` |

## 4. API

| API | 输入 | 输出 |
| --- | --- | --- |
| `run-flow` | target + 选择器 + seed 表/context | context |
| `run-stage` | target + 单个层名 + seed 表/context | 该层 `provides` 的值（hash），不含 seed |
| `select-stages` | 选择器 | 扁平层名列表 |
| `flow-value` | context + 名字 | 值 |
| `stage-table` / `stage-names` | — / 名字 | stage 表 / 层名列表 |
| `stage-groups` / `group-names` | — | 层组表 / 组名列表 |
| `providers-of` | 值名字 | 能产出它的 stage 名（排好序） |
| `default-flow` | — | `'(expand-data flatten expand-pseudo analyze dce relax encode)` |
| `(struct stage name requires provides run doc)` | `run` 接收 `(in target)` | — |

## 5. 规则

1. **单层、层组、片段都只是选择器**。选择器展开后就是一个层名列表；可选性 = 不在列表里。
2. **顺序 = 列表顺序**。同一个 stage 可以写两次；两个 stage 的 `provides` 相同就后者覆盖。
3. **平层随便换**：`layout` 和 `relax` 的 `requires`/`provides` 完全一样（`relax` 内部反复跑
   `layout`，所以写 `relax` 就够了，写 `layout` 则不做松弛），`dce` 可以写多次。
4. **依赖在运行到那一步时才检查**，不是预先校验：所以“先 `expand-data` 再 `flatten`”
   和“直接 seed `data-items` 再 `flatten`”都对。
5. **外部输入必须显式给**：没有数据也要写 `(cons 'data-items '())`。
6. **context 可以续跑**：`run-flow` 会复制 seed/context 到新的可变 hash，不修改传入的 context。
7. **`run-stage` 只跑一层**：适合单层单元测试；它只返回该层 `provides` 的值。

## 6. 不归本层管

- 各层的输入输出语义（见各自 `DESIGN.md`）。
- “最佳层序”：默认流只是常见组合，不是唯一正确答案。
- 目标选择 / 打包（`build` → 文件）：还没做。

## 7. 测试与 demo

`flow/test.rkt`：阶段表、默认流字节、可选层（关掉 `dce` 后死块留下）、
顺序敏感、依赖缺失/未知层/未知组、层组与选择器展开、单层 `run-stage`、
context 续跑、平层重复/互换。

`flow/demo.rkt`：打印阶段表 + 层组 → 跑默认流 → 去掉 `dce` 对比 → 故意少写一层/写错层看报错。

## 8. 已知缺口

- 没有并行 / 分支流（现在是严格线性）。
- 没有“跑到不动点”的通用写法；`relax` 自己内部循环。
- 没有把 `build` 落成文件（加载器格式）。
