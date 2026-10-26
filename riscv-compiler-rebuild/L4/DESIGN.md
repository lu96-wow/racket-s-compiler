# L4 布局计算

本层只做一件事：**给 item 分配段内偏移**。不做选择、不造 label、不填 scratch、不重排。

```
输入   program  list   ((label ...) (insn ...) ...)
       data     list   ((label ...) (bytes ...) (align n) ...)
       layout   list   ((segments (segment 名 kind start end align) ...)
                        (place 段名 链 ...) ...)
输出   (layout (segment ...) ... (symbols ...) (problems ...))
```

**代码里没有 `section`**：段归属全部写在 layout 的 `place` 行里。也没有 `primary` / `entry`。

## 1. 核心概念

| 概念 | 是什么 | 从哪来 |
| --- | --- | --- |
| `module` | 名字作用域前缀（L1 吃掉） | 程序/数据源 |
| **游程 run** | 从一条 `label` 到下一条 `label` 之间的 item，**放置的最小单位** | L4 自己切 |
| `segment` | 物理区间 `[start, end)` + kind | layout 输入 |
| `place` | `段名 + label 链` 的精确匹配规则 | layout 输入 |

游程的身份 = 它的 label 链；一个位置可以有多条链（连续写多条 `label`），命中任意一条即算匹配。

## 2. 段

```racket
(segment prog1 code #x100000 #x100FFF 16)   ; 名 kind start end align
```

自检：名字唯一、`start < end`、`start` 按 `align` 对齐、任意两段不重叠。

## 3. 放置规则

| 规则 | 内容 | 违反 |
| --- | --- | --- |
| P0 | 段归属只看 `place` 行，**精确匹配** label 链（`equal?`），不做前缀、不做默认 | `unplaced` |
| P0b | 同一个链被两行 `place` 抢 | `ambiguous-placement` |
| P0c | 开头的 item 在第一条 `label` 之前，没有身份 | `unlabeled-run` |
| P0d | `place` 指向未声明的段 | `unknown-segment`（该行不生效） |
| P1 | 段内 item 必须与段 kind 匹配 | `code-data-mixed` / `data-code-mixed` |
| P2 | 段内顺序 = **源顺序**（程序先、数据后，各自按出现顺序）；`place` 行的书写顺序无关 | — |
| P3 | 段内单游标从 `start` 起，`(align n)` 向上补齐，逐条累加 | — |
| P4 | 内容越过 `end` | `segment-overflow` |
| P5 | 段内没有 `(org ...)`；大空洞靠拆段 | 不支持 |
| P6 | 一个游程不跨段 | —（结构上保证） |
| P7 | `code` 段只许 指令 / `label` / `align`(4 的倍数)；`data`、`rodata` 段只许 `bytes` / `label` / `align` | 同 P1 |
| P8 | label 的偏移 = 所在位置的游标 | — |
| P9 | 填充字节由编码层写 `0x00` | — |
| P10 | 产物 `size` = 实际内容长度，另给 `start`/`end` | — |

## 4. 形式表（`forms.rkt`）

| item | 字节 |
| --- | --- |
| `label` | 0 |
| `bytes` | 元素个数 |
| `align n` | 由游标算 |
| `b*` | 4 |
| `branch-far` | 8 |
| `branch-indirect` | 12 |
| `jal` | 4 |
| `jump-far` / `call-far` / `la` | 8 |
| `c.*` | 2 |
| 其他 | 4 |

可达距离：`b*` 4096，`jal`/`branch-far` 1048576，`branch-indirect`/`jump-far`/`call-far`/`la` 不设限。

## 5. 校验（只记 problems，不抛异常）

```racket
((unplaced (main))
 (ambiguous-placement (main) a b)
 (unknown-segment nope)
 (unlabeled-run ((addi a0 a0 1)))
 (code-data-mixed prog1 4 (bytes 1 2))
 (data-code-mixed data1 0 (addi a0 a0 1))
 (segment-overflow prog1 8 7)
 (segment-misaligned prog1 #x1002 16)
 (segment-overlap a b)
 (segment-name-duplicated (a b a))
 (segment-bad-range b)
 (undefined-target prog1 0 (jal x0 (ghost)))
 (needs-far prog1 8 (jal x0 (prog1cold cold)) 2097144)
 (scratch-hole prog1 0 (branch-indirect a0 a1 (done))))
```

最后两类**不是错误**，是留给远跳转层（L5）的入口。

## 6. 远跳转层（L5，预留，不实现）

- 只保留层的位置与契约：`annotated -> program'`，只做「超范围的 item 升成远形式」和「有洞就留着」。
- 空槽规则：`(branch-indirect a b L)` 少一个参数 = 洞；`(branch-indirect s a b L)` 已填。
- 填槽方式（用户手写 / 用户规则 / 以后的分配器）不在本层定义。
- L4 只负责把 `needs-far` / `scratch-hole` 报出来。

## 7. 与真实工具链一致的地方

- 条件分支远形式 = **反向分支 + `jal`**（8 字节，无需 scratch），与 gas `md_convert_frag_branch`、LLVM `expandLongCondBr` 一致。
- 超过 ±1MB 才需要 scratch（`auipc + jalr`）；GAS 对此交给链接器报错，LLVM 在 machine 层用 `insertIndirectBranch` + reg scavenger。我们把它留给 L5，用显式空槽替代 scavenger。
- 顺序与重排：本层不重排。将来若要 hot/cold 或 fallthrough 聚集，应作为独立可选层（改游程顺序，再重跑 L4），不在本层偷偷做。
