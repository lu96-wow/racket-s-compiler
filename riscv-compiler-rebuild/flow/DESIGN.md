# flow 构建流（`flow/flow.rkt`）

> 用一张 stage 表和**一个名字列表**决定跑哪些层、什么顺序。
> `(list 'expand-data 'flatten 'expand-pseudo 'analyze 'dce 'relax 'encode)`
> 就是整条流水线；不写进列表的层就是关掉。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| 按列表顺序跑 stage | 任何实际的编译逻辑（都在各层里） |
| 每步检查依赖（`requires` 在不在） | 自动挑选层 / 自动排序 |
| 维护"在途值"（名字 → 值） | 判断某个层该不该跑（那是列表的事） |
| 依赖缺了说清"谁能提供" | 改各层的契约 |

## 2. 输入 / 输出

```racket
(run-flow (list 'expand-data 'flatten 'expand-pseudo 'analyze 'dce 'relax 'encode)
          '((rich-data . …)          ; 外部输入(seed)
            (program-items . …)
            (layout-spec . …)))
;; -> context（hash），用 (flow-value ctx 'build) 取出产物
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

**stage 表（顺序无关，跑的顺序只看列表）**

| stage | requires | provides |
| --- | --- | --- |
| `expand-data` | `rich-data` | `data-items` |
| `flatten` | `program-items` `data-items` | `program-items` `data-items` `names`（模块系统：provide/require 在这里解析） |
| `expand-pseudo` | `program-items` | `program-items` |
| `analyze` | `program-items` `data-items` | `program` |
| `dce` | `program` | `program` |
| `layout` | `program` `data-items` `layout-spec` | `layout` |
| `relax` | `program` `data-items` `layout-spec` | `layout` |
| `encode` | `layout` | `build` |

## 3. API

| API | 输入 | 输出 |
| --- | --- | --- |
| `run-flow` | 层名列表 + seed 表 | context |
| `flow-value` | context + 名字 | 值 |
| `stage-table` / `stage-names` | — / 名字 | stage 表 / 名字列表（说明用 `stage-doc` 取） |
| `providers-of` | 值名字 | 能产出它的 stage 名（排好序） |
| `default-flow` | — | `'(expand-data flatten expand-pseudo analyze dce relax encode)` |
| `(struct stage name requires provides run doc)` | — | — |

## 4. 规则

1. **可选 = 不在列表里**。没有 `#:enable` 之类的开关，列表本身就是开关。
2. **顺序 = 列表顺序**。同一个 stage 可以写两次；两个 stage 的 `provides` 相同就后者覆盖。
3. **平层随便换**：`layout` 和 `relax` 的 `requires`/`provides` 完全一样（`relax` 内部反复跑
   `layout`，所以写 `relax` 就够了，写 `layout` 则不做松弛），`dce` 可以写多次。
4. **依赖在运行到那一步时才检查**，不是预先校验：所以"先 `expand-data` 再 `flatten`"
   和"直接 seed `data-items` 再 `flatten`"都对。
5. **外部输入必须显式给**：没有数据也要写 `(cons 'data-items '())`。
6. **名字是契约**：层名和目录名现在一致，但流只认名字。

## 5. 不归本层管

- 各层的输入输出语义（见各自 `DESIGN.md`）。
- "最佳层序"：默认流只是常见组合，不是唯一正确答案。
- 目标选择 / 打包（`build` → 文件）：还没做。

## 6. 测试与 demo

`flow/test.rkt`（20 条）：阶段表、默认流字节、可选层（关掉 `dce` 后死块留下）、
顺序敏感（先 `analyze` 后 `expand-pseudo` 会失败）、依赖缺失与未知层名的报错、
平层重复/互换。

`flow/demo.rkt`：打印阶段表 → 跑默认流 → 去掉 `dce` 对比 → 故意少写一层/写错层看报错。

## 7. 已知缺口

- 没有并行 / 分支流（现在是严格线性）。
- 没有"跑到不动点"的通用写法；`relax` 自己内部循环。
- 没有把 `build` 落成文件（加载器格式）。
