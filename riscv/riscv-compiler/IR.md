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
| `load-units` | 可选 `extern-units`（+ 旧的外部元数据） | `extern-structs` + `extern-struct-provides` + `extern-label-provides` |
| `expand-struct` | `program-items` + `rich-data` (+ optional `extern-structs` / `extern-struct-provides`) | 展开后的 `program-items` + `rich-data` + `structs` + `struct-provides` |
| `expand-data` | rich 数据 | 核心数据 item |
| `flatten` | `program-items` + `data-items` (+ optional `externs` / `extern-label-provides`) | 完整链的 `program-items` + `data-items` + `names` + `exports` + `label-provides` + `module-requires` |
| `analyze` | `program-items` + `data-items` | `program`（blocks + flows） |
| `dce` | `program` | `program` |
| `emit-unit` | `program` + `data-items` (+ optional `structs` / `label-provides` / `struct-provides` / `module-requires`) | 布局前 `unit` |
| `layout` | `program` + `data-items` + `layout-spec` | `measured-layout` |
| `check` | `measured-layout` | `measured-layout`（追加 problems） |
| `bind-labels` | `measured-layout` | `bound-layout` |
| `encode` | `bound-layout` (+ optional `structs` / `label-provides` / `struct-provides` / `unit`) | `build`（布局镜像） |
| `emit-program` | `build` + `program` + `data-items` (+ optional `unit` / `extern-units` / `externs`) | `program`（最终 s-exp） |

## 关键类型

| 类型 | 形状 / 作用 |
| --- | --- |
| rich 数据 | `(b8 v)` / `(b16 v)` / `(bN-array n v…)` / `(utf-string[s] "…")` |
| 核心数据 item | `(value w v)` / `(bytes …)` / `(fill n b)` / `(pad n)` / `(align n)` / `(reserve n)` / `(label 链…)` |
| 伪指令 | native: `(mv …)` / `(ble L …)` / `(nop)`；`ret` 这类 ABI 伪指令不进入 core |
| 控制转移 | native: `(beq L a b)` / `(jal rd L)` / `(j L)`；显式形式 `(branch-jal …)` / `(branch-auipc-jalr …)` / `(jump-auipc-jalr …)` |
| `(la-pcrel rd 表达式)` | 取地址；auipc+addi，8 字节 |
| `(li rd 常量)` | 常量装载；尺寸由常量精确决定 |
| `(struct name (field type) …)` | 前端布局定义；展开后消失 |
| `(struct-data name (field value …) …)` | 静态数据实例；展开成 align/pad/value |
| `(sizeof name)` / `(offsetof name field)` | 编译期整数 |
| `(anchor 链 段名 偏移)` | measured 的 label 位置，无绝对地址 |
| `(symbol 链 段名 偏移 地址)` | bound 的最终符号 |
| `(problems …)` | 放置 / 段 / fallthrough / `undefined-target` / `out-of-range` / `zero-scratch` / `bad-scratch` / `la-too-far` / 最终宽度/容量 |
| measured-layout | `((phase measured) (origin …) (externs …) (segments …) (anchors …) (problems …))` |
| bound-layout | `((phase bound) (origin …) (segments …) (anchors …) (symbols …) (link …) (provides …) (problems …))` |
| `(link (base B) (symbol 链 地址) …)` | 对外的“名字 → 绝对地址”，`symbols` 的两列投影；输出里没有未解析项 |
| `(la-pcrel-li-add rd tmp 链)` | 前端显式选择的远 PC 相对装载地址；`tmp` 必需；尺寸是**常量上界**，短出来的补 `nop` |
| `(provides 链 …)` | 其中哪些名字是**对外**的（`flatten` 的导出集合；没有 `` (provide …) `` 时是全导出） |
| `structs` | `(struct-def (name 链) (size n) (align n) (fields (field (name f) (type t) (offset n) (size n) (align n)) …) (padding (align (n n) (offset n) (size n)) (pad (n n) (offset n) (size n)) …)) …)` |
| `label-provides` | `(label-provides (module (a) (provide 外部链 绝对链) …) …)`；按模块的 label 导出表 |
| `struct-provides` | 同上，只是 struct 名字空间 |
| `unit` | `(unit (format 1) (target …) (modules …) (declarations …))`；布局前接口 |
| `program` | `(program (internal …) (external …))`；根 module 带 `(base B)`，addresses 存相对 base 的偏移 |
| `build` | `(build (link …) (provides …) (structs …) (label-provides …) (struct-provides …) (unit …) (segment …) …)` |
| link 文件 | `link-file.rkt` 把 link 按 provides 过滤后写成**单独一个文件**，形状同 `(link …)`，可直接当下一份的输入 |

## 输入侧：外部符号

`externs` 是一个 seed（可省），值就是**上一份编译写出来的 link 文件内容**：

```scheme
(link (base #x80000000)
      (symbol (lib f) #x80001000)     ; 地址已知：参与距离判断，能做短跳
      (symbol (lib g) #f))            ; 地址未知：现在报 unlinked-external
```

用它的层：`flatten`（放行这些名字）、`check`（地址进距离判断 + 自检）。
`base` 只解析不参与算术；地址未知现在编不出来（没有 reloc 层）。

## 输入侧：unit

```scheme
(extern-units
  (unit ...))
```

`load-units` 把它转成现有的外部元数据；struct 声明在这里重新布局。
旧的 `extern-structs` / `extern-struct-provides` / `extern-label-provides` 仍然可用。

## 输入侧：外部 struct

`extern-structs` 是一个可选 seed。值可以是上一份 `(build …)`、它的
`(structs …)` 字段，或 `(struct-def …)` 列表：

```scheme
(extern-structs
  (structs
    (struct-def (name (lib point)) (size 8) (align 4)
                (fields …) (padding …))))
```

外部定义直接作为已算好的布局使用；本单元可以用完整链 `(lib point)` 引用，
也可以把上一份的 `struct-provides` 作为 `extern-struct-provides` 输入后用
`(require lib)` / `prefix-in` / `rename-in`。

## 输入侧：外部 label provides

`extern-label-provides` 接受上一份 build 的 `(label-provides …)` 字段，
让 `require` 能绑定到别的编译单元：

```scheme
(extern-label-provides
  (label-provides
    (module (lib) (provide (f) (lib f)))))
```

地址仍由 `externs` 提供；`extern-label-provides` 只补模块/别名信息。

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
