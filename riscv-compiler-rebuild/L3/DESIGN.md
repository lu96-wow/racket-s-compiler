# L3 控制流分析（`L3/insn.rkt` `L3/cfg.rkt` `L3/analyze.rkt`）

> 只**分析**，不改程序。输出"块 + 流"两份平行数据。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| 分类指令（分支/跳转/间接/陷阱/是否落下） | 改任何 item |
| 切块、算后继与物理顺序 | 尺寸 / 地址 / 段 |
| 标 `root?`（外部入口） | 判断真指令是否合法 |

## 2. 输入 / 输出

```racket
(analyze items)            ; items: 扁平 item 列表
(analyze items data-items) ; data 只用来算 roots（见 §4.4）
  -> (program blocks flows)

(block (链 ...) item ...)                              ; 身份 + 程序
(flow (succ 下标 ...) (fallthrough 下标|#f) (root? bool))
```

```racket
((blocks (block ((prog1 main)) (lwu t0 sp 8) (bge t1 t0 (prog1 done)))
         (block () (jal x0 (prog1cold cold))))
 (flows  (flow (succ 1 2) (fallthrough 1) (root? #t))
         (flow (succ 2) (fallthrough #f) (root? #f))))
```

`program` 是 `(struct program (blocks flows))`：两份数据**一一对应**，块的身份就是它的下标。

## 3. API

| 文件 | API |
| --- | --- |
| `analyze.rkt` | `analyze` `program?` `program-blocks` `program-flows` `block-head` `block-items` `make-block` `flow-succ` `flow-fallthrough` `flow-root?` `make-flow` `program->sexp` `sexp->program` `program-items` |
| `cfg.rkt` | `build-cfg` `cfg->lines` `cfg-reachable` `referenced-labels` `address-taken-paths` `basic-block` `graph` |
| `insn.rkt` | `branch-instruction?` `jump-instruction?` `indirect-instruction?` `trap-instruction?` `ends-block?` `falls-through?` `unconditional-jump?` `jump-target` `jump-register` `zero-register?` `label-form?` `label-path` `normalize-path` |

## 4. 规则

### 4.1 块边界只由控制流决定

- 程序开头；
- **控制转移的目标 label**；
- `ends-block?` 的指令之后。

非目标的 `label` **不是**边界，它作为"位置标记"留在块的程序里 —— 一个块可以有多个名字、
也可以没有名字。按 label 搬代码会把"块"和"位置"混为一谈。

### 4.2 两条控制流事实

| 字段 | 含义 | 判据 |
| --- | --- | --- |
| `succ` | 后继块下标 | 分支：目标 + 顺序；`jal x0`：只有目标；调用：目标 + 顺序 |
| `fallthrough` | **物理**下一条是哪个块 | `falls-through?`：普通指令/分支会；`jal ra`/`jalr ra`/`ecall` 会（返回地址 = pc+4）；`jal x0`/`jalr x0`/`ebreak` 不会 |

调用和 `ecall` 也算"会落下"：它们的返回地址就是 pc+4，所以下一条必须紧挨着。

### 4.3 远形式按 link 判断

`(branch-far <cond> a b L)` / `(branch-indirect [s] <cond> a b L)` 是条件分支（会落下）；
`(jump-far link [s] L)` 由 `link` 决定：`ra` 是调用（会落下），`x0` 是不回来。

### 4.4 `root?` = 外部入口

```
root? = 下标 0（程序入口）
      或（有间接跳转时）该块的 label 出现在"地址被取过"的集合里
```

"地址被取过"包含**数据侧**：`(value 宽度 (label+ 链 加数))` 把链的地址写进了数据
（函数指针表 / 跳转表），所以 `analyze` 的第二个参数也要吃 data item。
**data item 不进块、不进 CFG，只贡献 roots。**

没有间接跳转时不算 —— 否则数据里一个没人用的地址会把死代码钉活。

## 5. 不归本层管

- 合法性（操作数、立即数范围）：属于 L7。
- 尺寸、地址：属于 L5。
- 删块 / 合并：属于 L4。

## 6. 测试（`L3/test.rkt`，176 条）

分类、块边界、`succ`/`fallthrough`、`root?`（含数据侧取地址）、CFG 打印与可达性、链作为
跳转目标、`program->sexp` / `sexp->program` 往返。

## 7. 已知缺口

- `bge`/`jalr` 之外的"非法断点"（例如 `(jalr x0 ra 0)` 会不会返回）一律按操作数判断，不做语义分析。
- `sexp->program` 会校验 blocks/flows 等长，`analyze` / L4 直接构造时不校验（内部不变量）。
