# 各层 s-expression 设计

> 一页看懂每层：**解决什么功能、吃什么/吐什么 s-exp、为什么形状是这样**。
> 跨层铁律见 [`ARCHITECTURE.md`](ARCHITECTURE.md)，每层细节见各自的 `DESIGN.md`。

## 总图

```
rich-data ─→ expand-data ─┐
                          ↓
program-items ─┬─→ flatten ─→ expand-pseudo ─→ analyze ─→ dce ─→ relax ─→ encode
data-items ────┘                                │         │       │         │
                                                ↓         ↓       ↓         ↓
                                             program   program  layout   build
```

每层都是纯函数；`flow` 只负责按名字列表调用它们。

## 共同约定

| 项 | 约定 |
| --- | --- |
| item | 一个真列表，头是助记符/形式名，例如 `(lwu t0 sp 8)` |
| 名字 | symbol / string / number |
| 链 | 非空名字列表，例如 `(prog1 main)` |
| 地址表达式 | 整数 \| `(链)` \| `(+ a b …)` \| `(- a b …)`，≥2 个操作数 |
| 入口壳 | 旧写法 `(quote …)` / `(begin …)` 入口接受，出口一律 plain list |
| 层间载荷 | 只传 plain list 或 `(struct program …)`；不认识的 item 原样透传 |

`sexp.rkt` 提供 `form?` / `name?` / `path?` / `normalize-path` / `as-items` 和地址表达式判定；
`target.rkt` 提供 XLEN、端序、扩展集、填充策略。它们是共享事实，不是层。

---

## expand-data

**功能**：把“人写的数据定义”变成核心数据 item。负责宽度、值域、UTF-8、数组压缩、地址字透传。

| 项 | 内容 |
| --- | --- |
| 输入 | `(b8/b16/b32/b64 v)`、`(bN-array n v...)`、`(utf-string[s] "…")`、`(label …)`、`(bytes …)`、`(fill n b)`、`(pad n)`、`(align n)`、`(module …)` 结构壳 |
| 输出 | `(value 宽度 值)`、`(bytes …)`、`(fill n b)`、`(pad n)`、`(align n)`、`(label …)`；module 壳原样保留 |

**为什么这样设计**

- rich 形式只服务“数据定义”：`b16` 的宽度和值域是数据问题，端序是“变字节”时的问题，所以输出只交宽度+值。
- 数组只有在与端序无关时才压成 `(fill n b)`；否则一个元素一条 `(value w v)`，不能提前合并成字节。
- 地址表达式不求值：链的绝对地址要等 layout 建符号表，字节要等 encode。

**不归本层管**：端序、段、偏移、地址求值、真 reloc。

细节：[`expand-data/DESIGN.md`](expand-data/DESIGN.md)

---

## flatten

**功能**：编译期纯名字解析。把 `module` / `provide` / `require` / `prefix-in` / `rename-in` / `rename-out` 解析成完整链，之后的层看不到模块。

| 项 | 内容 |
| --- | --- |
| 输入 | `(module 名 item...)`、`(provide …)`、`(require …)`、`(label 链...)`，以及操作数里带链的任意 item |
| 输出 | 去掉 module/provide/require 壳；label 和引用都变成完整链；可选一张 `链 -> 位置` 名字表 |

**为什么这样设计**

- 模块只影响“名字可见性”，不影响指令、尺寸、地址，所以这层只该做名字解析。
- 默认私有、re-export、循环 `require` 都是名字解析问题，不需要运行时初始化顺序。
- 链是身份：`(label a f)` 和 `(label a g)` 是同一位置的多个名字；解析后所有层只认完整链。

**不归本层管**：指令拼写、伪指令、数据展开、段/偏移/尺寸。

细节：[`flatten/DESIGN.md`](flatten/DESIGN.md)

---

## expand-pseudo

**功能**：表驱动伪指令替换。一条 item 可以展开成一条或多条真指令。

| 项 | 内容 |
| --- | --- |
| 输入 | `((load-32 t0 sp 8) (store-64 ra sp 16) (move a0 a1) …)` |
| 输出 | `((lwu t0 sp 8) (sd ra sp 16) (add a0 a1 x0) …)`；不认识的 form 原样保留 |

**为什么这样设计**

- 伪指令只是拼写和操作数顺序的糖，不改变控制流语义；长度/地址留给 layout。
- 逻辑与表分离：加一种写法/一条伪指令只改表数据，遍历和匹配逻辑不动。
- 形状不匹配就透传，真正的指令合法性统一留给 encode（`riscv-asm`）。

**不归本层管**：结果是不是合法指令、尺寸、`li` / `la`（它们要最终地址）。

细节：[`expand-pseudo/DESIGN.md`](expand-pseudo/DESIGN.md)

---

## analyze

**功能**：控制流分析。把线性 item 切成块，并单独给出每个块的后继、顺序下落、root 标记。

| 项 | 内容 |
| --- | --- |
| 输入 | 扁平程序 item 列表；第二个参数是 data item（只用来找“地址被取过”的块） |
| 输出 | `(struct program blocks flows)`；`block = (block <头链列表> item...)`，`flow = (flow (succ id...) (fallthrough id|#f) (root? bool))` |

**为什么这样设计**

- 块边界只由控制流决定：程序开头、跳转目标 label、`ends-block?` 指令之后；非目标 label 只是块内位置标记。
- `succ` 服务可达性，`fallthrough` 服务物理布局；两者分开，才能区分“跳过去”和“顺序落下去”。
- data item 不进 CFG，只贡献 root：数据里的地址字等于把入口交给了外部，但只有存在间接跳转时才需要保活。

**不归本层管**：改程序、指令合法性、尺寸/地址、删块。

细节：[`analyze/DESIGN.md`](analyze/DESIGN.md)

---

## dce

**功能**：死代码消除。删不可达块、删“跳到紧邻下一块”的转移、空块并进下一块。

| 项 | 内容 |
| --- | --- |
| 输入 | `program`（blocks + flows） |
| 输出 | `program`（两个列表保持一一对应，id 重新编号） |

**为什么这样设计**

- blocks 和 flows 是平行数据，任何 pass 都必须同时改两份并重映射 id，否则块身份会错。
- 只做三种保守变换：可达性、冗余转移、空块合并；不改 item 内容、不造 label、不补跳。
- 远形式（`branch-far` / `jump-far`）也按同一套控制转移判断，所以 DCE 不关心松弛前后的形式。

**不归本层管**：补 `broken-fallthrough`、分支松弛、尺寸/地址、块重排。

细节：[`dce/DESIGN.md`](dce/DESIGN.md)

---

## layout

**功能**：布局计算。把块/数据游程放进段，算出偏移、尺寸、符号表，并报告放置/范围问题。

| 项 | 内容 |
| --- | --- |
| 输入 | `program` + data item + `((segments (segment (name …) (kind …) (start …) (end …) (align …)) …) (place 段名 链 …) …)` |
| 输出 | `((segments (segment … (items (offset k item) ...) (size n)) …) (symbols (symbol 链 段名 偏移 绝对地址) …) (problems …))` |

**为什么这样设计**

- 只有 layout 持有段和符号表，所以只有它能把 `(align n)` 换算成精确的 `(pad n)`、判断分支/地址范围。
- 代码里没有 section：段归属只写在 `place` 行里，按精确链匹配；不自动按 kind 落位。
- 不认识的 item 一律当“不透明代码 4 字节（`c.*` 2 字节）”：真实指令合法性属于 encode。
- `needs-far` / `scratch-hole` 是交接点：前者给 relax，后者给尚未实现的寄存器使用层。

**不归本层管**：选择远形式、填 scratch、补 fallthrough 跳转、指令合法性、端序。

细节：[`layout/DESIGN.md`](layout/DESIGN.md)

---

## relax

**功能**：分支松弛。把够不着的控制转移升成大一号的形式，直到全部够得着；内部反复驱动 layout。

| 项 | 内容 |
| --- | --- |
| 输入 | `program` + data item + layout 输入 |
| 输出 | `layout`（`needs-far` 已销完；可能留下 `scratch-hole`） |

**为什么这样设计**

- layout 产物已经排好偏移、没有块结构，改完没法重排，所以 relax 不能吃 layout 产物，只能“改 program → 重跑 layout”。
- 每次提升都让 item 变长，距离只会变大，“太远”集合单调递增，因此一定收敛。
- 不造 label、不拆块，所以 `place` 行永远有效，`fallthrough` 不会被松弛剪断。
- scratch 空槽不填：那需要活跃性信息，属于更后面的寄存器使用层。

**不归本层管**：填 scratch、造 label、改 CFG、补跳、重排、数据宽度。

细节：[`relax/DESIGN.md`](relax/DESIGN.md)

---

## encode

**功能**：把 layout 变成每个段一坨字节。负责端序、填充、`li`/`la`/远形式、原子指令与 `fence` 的语法，以及把指令交给 `riscv-asm` 编码。

| 项 | 内容 |
| --- | --- |
| 输入 | 没有 problems 的 layout |
| 输出 | `(build (segment (name …) (kind …) (start …) (size …) (bytes #vu8…)) …)` |

**为什么这样设计**

- 端序、填充策略、指令编码都属于“变二进制”，集中在这里；layout 只量宽度，不落字节。
- `(offset k item)` 是断言：实际写出的字节数必须正好到达 `k`，这样能抓住 layout/encode 对尺寸理解不一致。
- 有任何 problem 就拒绝出产物：`needs-far` / `scratch-hole` / `undefined-target` 都不是 encode 能偷偷修的东西。
- 操作数顺序由一张“函数参数位置 ← s-exp 位置”的表处理，因为 `riscv-opcodes` 的声明顺序不是汇编写法。

**不归本层管**：选指令、布局、松弛、填 scratch、加载器格式。

细节：[`encode/DESIGN.md`](encode/DESIGN.md)

---

## flow

**功能**：用一张 stage 表 + **选择器**串起各层。选择器可以写单层、预定义层组，或任意片段；`run-stage` 可以只跑一层。

| 项 | 内容 |
| --- | --- |
| 输入 | target + 选择器 + seed 表/context，例如 `(run-flow target-rv64-base 'analyze seeds)`、`(run-flow target-rv64-base '(frontend ir backend) seeds)`、`(run-stage target-rv64-base 'flatten seeds)` |
| 输出 | `run-flow` → context（hash）；`run-stage` → 该层 `provides` 的值（hash） |

**预定义层组**

| 组名 | 展开 |
| --- | --- |
| `frontend` | `expand-data flatten expand-pseudo` |
| `ir` | `analyze dce` |
| `backend` | `relax encode`（layout 在 relax 内部跑） |
| `all` | `default-flow` |

**为什么这样设计**

- 单层、层组、片段都只是选择器：展开后仍是一个层名列表，顺序和可选性没有新语义。
- 每个 stage 只声明 `requires` / `provides`，不自动排序、不自动选层；依赖在运行到那一步时才检查。
- seed 可以直接是上一趟的 context，所以能“跑前一段 → 单独测下一层/下一段”，不必手写中间值。
- 在途值的名字就是契约：`rich-data` / `data-items` / `program-items` / `names` / `program` / `layout` / `build`。

**不归本层管**：任何实际编译逻辑。

细节：[`flow/DESIGN.md`](flow/DESIGN.md)

---

## 在途值速查

| 名字 | 形状 | 谁产 |
| --- | --- | --- |
| `rich-data` | 人写的 rich 数据 | seed |
| `data-items` | 核心数据 item | `expand-data` / `flatten` / seed |
| `program-items` | 扁平程序 item（可含 module 壳） | seed / `flatten` / `expand-pseudo` |
| `names` | 完整链 → 位置 | `flatten` |
| `program` | `(struct program blocks flows)` | `analyze` / `dce` |
| `layout` | segments + symbols + problems | `layout` / `relax` |
| `build` | 每段字节 | `encode` |
