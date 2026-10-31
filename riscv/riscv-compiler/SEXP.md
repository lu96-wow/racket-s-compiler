# s-expression 速查

> 每层的完整说明在各自的 `DESIGN.md`；跨层硬边界在 [`flow/DESIGN.md`](flow/DESIGN.md)。

## 通用约定

| 项 | 形状 |
| --- | --- |
| item | 真列表，例如 `(lwu t0 sp 8)` |
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
| `expand-pseudo` | `program-items` | `program-items` |
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
| 伪指令 | `(move …)` / `(load-32 …)` / `(ble …)` 等，由表替换 |
| 控制转移 | `(bge a b L)` / `(jal rd L)` / `(branch-far …)` / `(branch-indirect …)` / `(jump-far …)` |
| `(la rd [tmp] 表达式)` | 取地址；近形式 8 字节 |
| `(li rd 常量)` | 常量装载；尺寸由常量精确决定 |
| `(anchor 链 段名 偏移)` | measured 的 label 位置，无绝对地址 |
| `(symbol 链 段名 偏移 地址)` | bound 的最终符号 |
| `(requests …)` | `needs-far` / `scratch-hole` / `la-too-far`，交给后续 pass |
| `(problems …)` | 放置 / 段 / fallthrough / `undefined-target` / 最终宽度/容量 |
| measured-layout | `((phase measured) (segments …) (anchors …) (requests …) (problems …))` |
| bound-layout | `((phase bound) (segments …) (anchors …) (symbols …) (requests …) (problems …))` |
| `build` | `(build (segment (name …) (kind …) (start …) (size …) (bytes #vu8…)) …)` |

## 段 kind

`kind` 只回答两件事：**这一段收哪些 item**、**对齐补出来的空间怎么落**。
它不表达权限、不表达“里面放什么数据”。

| kind | 收的 item | `(align n)` 的产物 | 文件字节 |
| --- | --- | --- | --- |
| `code` | `label` / `align` / `pad` / 指令 | `(pad n)`，填 `nop` | 有 |
| `data` | `label` / `align` / `pad` / `bytes` / `fill` / `value` | `(pad n)`，填 0 | 有 |
| `hole` | `label` / `align` / `reserve` | `(reserve n)` | **没有** |

```scheme
(segment (name bss) (kind hole) (start #x2000) (end #x2100) (align 8))
```

`hole` 段只回答“这些地址存在”；内容不由本产物定义（加载器 / 程序 / 硬件决定），
所以 `build` 里它的 `bytes` 是 `#""`，`size` 照旧。谁把它清成 0、什么时候清，
是前端/平台的事，后端不参与。guard page、MMIO 窗口也是 `hole`，不需要额外语法。

`(reserve n)` 只在 `hole` 段合法；`hole` 段不接受 `bytes` / `fill` / `value` / `pad` / 指令
（否则地址和文件字节的对应关系就不成立了）。
