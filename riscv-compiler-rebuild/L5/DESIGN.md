# L5 布局计算

## 0. 上游: L3 分析 / L4 死代码消除

label 不等于块：块由 **leader**（label、`ends-block?` 指令之后、程序开头）决定，一个块可能没有 label，一个 label 也可能只是同一块里的另一个名字。按 label 搬代码会把「块」和「位置」混为一谈；更危险的是**顺序执行（fallthrough）**被段切断时，按名字搬动的布局层根本看不见。

所以：**L3 只做分析并输出块列表（不改程序），L4 做死代码消除（会改控制流），
L5 按块放置并检查 fallthrough 没被剪断。**

L4 的 pass：`drop-unreachable` → `drop-transfers-to-next-block` → `merge-empty-blocks`，
每个都同步修 `succ` / `fallthrough`，跑到不动点。

## 1. 块列表（L3 输出、L4 输入输出、L5 输入）

块是 Racket struct（`L3/analyze.rkt` 里的 `block`），不是 s-exp；
`blocks->sexp` / `sexp->blocks` 只用于打印和写字面量。

```racket
(struct block (id labels insns succ fallthrough root?) #:transparent)
```


打印出来长这样：

```racket
((block (id 0) (labels (prog1 main)) (insns (lwu t0 sp 8) (bge t1 t0 (prog1 done)))
        (succ 1 3) (fallthrough 1) (root? #t))
 (block (id 1) (labels) (insns (jal x0 (prog1cold cold))) (succ 2) (fallthrough #f) (root? #f))
 ...)
```

| 字段 | 含义 |
| --- | --- |
| `id` | 块身份（L4 报错/检查用） |
| `labels` | 块头的所有链（一个位置多名都在这里）；放置规则只认它 |
| `insns` | 块内容 |
| `succ` | 后继块 id |
| `fallthrough` | **物理下一条**是哪个块；`#f` 表示不以顺序方式落下去 |
| `root?` | 分析层算好的可达性根（入口 / 被外部引用 / 地址被取过）；后续层不用再懂指令语义 |

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
data    : 普通 item 列表 ((label ...) (bytes ...) (align n) ...)
layout  : ((segments (segment 名 kind start end align) ...)
           (place 段名 链 ...) ...)
```

代码里**没有 `section`**，也没有 `primary` / `entry`。

## 3. 放置

- **单位**：代码用块；数据用「label 游程」（数据没有控制流）。
- **place 行**：`(place 段名 链 ...)`，按**精确链**匹配（`equal?`），不做前缀、不按 kind 自动落位。
- **region**：命中的块是锚点；之后直到下一个锚点的块跟随它（没有身份的东西只能跟着有身份的前驱）。
- **顺序**：段内按源顺序（程序先、数据后），`place` 行书写顺序无关。
- **fallthrough 检查**：对每个 `fallthrough = j` 的块 i，块 j 必须是 i 在同一段里的**物理下一块**；否则 `broken-fallthrough`。补指令/插跳转留给 L5，L4 只报。

## 4. 段与度量

```racket
(segment prog1 code #x100000 #x100FFF 16)   ; 名 kind start end align
```

自检：名字唯一、`start < end`、`start` 按 `align` 对齐、区间不重叠。

段内单游标从 `start` 起，`label` 不占字节只记偏移，`(align n)` 向上补齐补 0，其余按形式表累加。
产物里每条 item 都带偏移注解 `(offset 偏移 item)`：

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
((unplaced-block 0 ((main)))                 ; 块没有锚点
 (unplaced (data1 table))                    ; 数据游程没有锚点
 (unlabeled-run ((bytes 1)))                 ; 数据开头没有 label
 (ambiguous-placement (main) a b)            ; 两行 place 抢同一个链
 (unknown-segment nope)                      ; place 指向未声明的段
 (broken-fallthrough 0 1 ((a)) ((b)))        ; 顺序执行被段/区段剪断
 (code-data-mixed prog1 4 (bytes 1 2))       ; 数据落进 code 段
 (data-code-mixed data1 0 (addi a0 a0 1))    ; 指令落进 data 段
 (code-align-not-4 prog1 8 2)                ; code 段里 align 不是 4 的倍数
 (segment-overflow prog1 8 7)
 (segment-misaligned prog1 #x1002 16)
 (segment-overlap a b)
 (segment-name-duplicated (a b a))
 (segment-bad-range b)
 (undefined-target s1 0 (jal x0 (ghost)))
 (needs-far prog1 8 (jal x0 (prog1cold cold)) 2097144)   ; 留给 L5
 (scratch-hole prog1 0 (branch-indirect a0 a1 (done))))  ; 留给 L5
```

最后两类不是错误，是远跳转层（L5）的入口。

## 6. 远跳转层（L5，预留，不实现）

- 契约：`annotated -> program'`，只做「超范围的 item 升成远形式」和「有洞就留着」。
- 空槽规则：`(branch-indirect a b L)` 少一个参数 = 洞；`(branch-indirect s a b L)` 已填。
- 填槽方式不在本层定义。
- 补 fallthrough 跳转、trampoline、块重排都属于这一层或更后面的层。

## 7. 与真实工具链一致的地方

- 条件分支远形式 = **反向分支 + `jal`**（8 字节，无 scratch），与 gas `md_convert_frag_branch`、LLVM `expandLongCondBr` 一致。
- 超过 ±1MB 才需要 scratch（`auipc + jalr`）；GAS 交给链接器报错，LLVM 在 machine 层用 `insertIndirectBranch` + reg scavenger。我们留给 L5，用显式空槽替代 scavenger。
- 顺序执行跨段 = 必须显式跳转；真实工具链里由 `.section`/链接脚本决定，报错方式就是「这里断了」。我们用 `broken-fallthrough` 显式化。
