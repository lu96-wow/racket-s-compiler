# riscv-compiler IR 类型

> 本文只列层间类型。人写的汇编表面语法见 [`SYNTAX.md`](SYNTAX.md)；
> 每层的完整说明在各自的 `DESIGN.md`；跨层硬边界在 [`flow/DESIGN.md`](flow/DESIGN.md)。

## 通用约定

| 项 | 形状 |
| --- | --- |
| item | 真列表，例如 `(lbu t0 sp 8)`；操作数顺序是 native |
| 名字 | symbol / string / number |
| 链 | 非空名字列表，例如 `(prog1 main)` |
| 地址表达式 | 整数 \| `(链)` \| `(+ a b …)` \| `(- a b …)` |
| 入口壳 | 接受 `(quote …)` / `(begin …)`，出口一律 plain list |
| 层间载荷 | plain list 或 `(struct program …)` |

`sexp.rkt` 提供形状判定、`as-items`、地址表达式判定和求值：

```racket
(eval-address expr resolve)   ; resolve : 链 -> 整数 | #f
```

`target.rkt` 提供 XLEN、扩展集、`integer->bytes`、`padding-bytes`。端序固定 little。

## 层间类型

| 层 | 输入 | 输出 |
| --- | --- | --- |
| `expand-data` | rich 数据 | 核心数据 item |
| `flatten` | `program-items` + `data-items` | 完整链的 `program-items` + `data-items` + `names` |
| `expand-pseudo` | `program-items` | `program-items`（可选：别名 → native） |
| `analyze` | `program-items` + `data-items` | `program`（blocks + flows） |
| `dce` | `program` | `program` |
| `layout` | `program` + `data-items` + `layout-spec` | `measured-layout` |
| `relax` | 同 layout | `measured-layout` |
| `bind-labels` | `measured-layout` | `bound-layout` |
| `encode` | `bound-layout` | `build` |

## 关键类型

| 类型 | 形状 / 作用 |
| --- | --- |
| rich 数据 | `(b8 v)` / `(b16 v)` / `(bN-array n v…)` / `(utf-string[s] "…")` |
| 核心数据 item | `(value w v)` / `(bytes …)` / `(fill n b)` / `(pad n)` / `(align n)` / `(reserve n)` / `(label 链…)` |
| 伪指令 | native: `(mv …)` / `(ble L …)` / `(nop)`；`ret` 这类 ABI 伪指令不进入 core |
| 控制转移 | native: `(beq L a b)` / `(jal rd L)` / `(j L)`；远形式 `(branch-far …)` / `(branch-indirect …)` / `(jump-far …)` |
| `(la rd [tmp] 表达式)` | 取地址；近形式 8 字节 |
| `(li rd 常量)` | 常量装载；尺寸由常量精确决定 |
| `(anchor 链 段名 偏移)` | measured 的 label 位置，无绝对地址 |
| `(symbol 链 段名 偏移 地址)` | bound 的最终符号 |
| `(requests …)` | `needs-far` / `scratch-hole` / `la-too-far`，交给后续 pass |
| `(problems …)` | 放置 / 段 / fallthrough / `undefined-target` / 最终宽度/容量 |
| measured-layout | `((phase measured) (origin …) (segments …) (anchors …) (requests …) (problems …))` |
| bound-layout | `((phase bound) (origin …) (segments …) (anchors …) (symbols …) (link …) (requests …) (problems …))` |
| `(link (base B) (symbol 链 地址) …)` | 对外的“名字 → 绝对地址”，`symbols` 的两列投影；输出里没有未解析项 |
| `(provides 链 …)` | 其中哪些名字是**对外**的（`flatten` 的导出集合；没有 `` (provide …) `` 时是全导出） |
| `build` | `(build (link …) (provides …) (segment (name …) (kind …) (start …) (size …) (bytes #vu8…)) …)` |
| link 文件 | `link-file.rkt` 把 link 按 provides 过滤后写成**单独一个文件**，形状同 `(link …)`，可直接当下一份的输入 |

## 段 kind

`kind` 只回答两件事：**这一段收哪些 item**、**对齐补出来的空间怎么落**。
它不表达权限、不表达“里面放什么数据”。

| kind | 收的 item | `(align n)` 的产物 | 文件字节 |
| --- | --- | --- | --- |
| `code` | `label` / `align` / `pad` / 指令 | `(pad n)`，填 `nop` | 有 |
| `data` | `label` / `align` / `pad` / `bytes` / `fill` / `value` | `(pad n)`，填 0 | 有 |
| `hole` | `label` / `align` / `reserve` | `(reserve n)` | **没有** |

```scheme
(segment (name bss) (kind hole) (align 4096) (size #x2000))   ; 起点由 layout 求解
```

段的形状：`(segment (name s) (kind k) (align n) [(start a)] [(end e) | (size z)])`。
`(start …)` 是**解**，可以不给；`(size …)` / `(end …)` 是容量约束（至少给一个）；
`(align …)` 是对齐约束。缺 `start` 时 `layout` 从 spec 的 `(origin …)` 起按 `align`
递增求解 —— **谁分配地址，谁就能看到约束**。

`hole` 段只回答“这些地址存在”；内容不由本产物定义（加载器 / 程序 / 硬件决定），
所以 `build` 里它的 `bytes` 是 `#""`，`size` 照旧。谁把它清成 0、什么时候清，
是前端/平台的事，后端不参与。guard page、MMIO 窗口也是 `hole`，不需要额外语法。

`(reserve n)` 只在 `hole` 段合法；`hole` 段不接受 `bytes` / `fill` / `value` / `pad` / 指令
（否则地址和文件字节的对应关系就不成立了）。
