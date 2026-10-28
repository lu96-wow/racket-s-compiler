# 架构总览（索引 + 规范）

> **本文件只做两件事**：给出全局地图，和写死跨层规矩。
> 每层的细节在各自的 `DESIGN.md` 里，本文件不重复。

## 0. 文档地图

| 文档 | 讲什么 |
| --- | --- |
| `ARCHITECTURE.md`（本文） | 分层地图、词汇边界、跨层铁律、IO 形状、形式归属、缺口清单、文档规范 |
| `expand-data/DESIGN.md` | 数据定义：宽度 / 值域 / 字符串 / 数组 / 地址字 |
| `flatten/DESIGN.md` | 模块展平 + 链式查表（只做名字） |
| `expand-pseudo/DESIGN.md` | 伪指令替换表 |
| `analyze/DESIGN.md` | 控制流分析：块、流、root |
| `dce/DESIGN.md` | 死代码消除 |
| `layout/DESIGN.md` | 布局：放置、度量、符号表、范围检查、problems |
| `relax/DESIGN.md` | 分支松弛（只升形式） |
| `encode/DESIGN.md` | 编码：操作数顺序、端序、字节规则 |
| `../riscv-asm/README.md` | 指令编码表（生成器 + 运行时），encode 的编码来源 |
| `../riscv-help/DESIGN.md` | `li` / `la` / 远分支 / 远跳转的展开器 |

## 1. 分层总图

```
      rich 数据 ─→ expand-data ─┐
                                │
source(多输入)                  │  每层都是纯函数, 可单独测
──────────────                  ↓
program list ┐
data    list ├─ flatten ─→ expand-pseudo ─→ analyze ─→ dce ─→ relax ─→ encode
layout  list ┘                items          program    program  layout   bytes
```

名字就是层名，也是目录名。**跑哪些层由 `flow` 的列表决定**：

```racket
(run-flow '(expand-data flatten expand-pseudo analyze dce relax encode) seeds)
```

| stage | 文件 | 一句话 | 读 | 写 | 细节 |
| --- | --- | --- | --- | --- | --- |
| `expand-data` | `expand-data/expand.rkt` | 数据定义 | `rich-data` | `data-items` | [`expand-data/DESIGN.md`](expand-data/DESIGN.md) |
| `flatten` | `flatten/flatten.rkt` | 模块系统（provide/require）+ 链式查表 | `program-items` `data-items` | 同左 + `names` | [`flatten/DESIGN.md`](flatten/DESIGN.md) |
| `expand-pseudo` | `expand-pseudo/rewrite.rkt` | 伪指令替换 | `program-items` | `program-items` | [`expand-pseudo/DESIGN.md`](expand-pseudo/DESIGN.md) |
| `analyze` | `analyze/insn.rkt` `analyze/cfg.rkt` `analyze/analyze.rkt` | 控制流分析（只分析） | `program-items` `data-items` | `program` | [`analyze/DESIGN.md`](analyze/DESIGN.md) |
| `dce` | `dce/dce.rkt` | 死代码消除 | `program` | `program` | [`dce/DESIGN.md`](dce/DESIGN.md) |
| `layout` | `layout/forms.rkt` `layout/layout.rkt` | 布局计算 | `program` `data-items` `layout-spec` | `layout` | [`layout/DESIGN.md`](layout/DESIGN.md) |
| `relax` | `relax/relax.rkt` | 分支松弛（内部反复跑 layout） | 同 `layout` | `layout` | [`relax/DESIGN.md`](relax/DESIGN.md) |
| `encode` | `encode/insn.rkt` `encode/encode.rkt` | 编码 | `layout` | `build` | [`encode/DESIGN.md`](encode/DESIGN.md) |
| `flow` | `flow/flow.rkt` | 构建流本身 | 层名列表 + seed | context | [`flow/DESIGN.md`](flow/DESIGN.md) |

可选性、顺序、平层（`layout` 与 `relax` 同进同出）都由那张列表表达，见 `flow/DESIGN.md`。

不属于任何层的两个**纯工具/纯事实**模块（顶层）：

| 文件 | 内容 | 谁用 |
| --- | --- | --- |
| `sexp.rkt` | `form?` `name?` `path?` `normalize-path` `as-items`（旧壳 `quote`/`begin` 也认）地址表达式 `arith-head?` / `arith-form?` / `address-expr?` / `address-expr-chains` | 除了 flow 之外的所有层 |
| `target.rkt` | `target-xlen` `target-endianness` `target-extensions` `integer->bytes` `padding-bytes` | layout（XLEN）、encode（端序/填充/扩展集） |

它们不是层：没有输入输出契约，只有"同一个形状/事实"。各层可以**原样 re-provide** 其中的绑定，
所以 `(require "analyze/analyze.rkt" "layout/layout.rkt")` 不会因为都 provide `as-items` 而冲突。

两个外部包：

| 包 | 管什么 | 谁用 |
| --- | --- | --- |
| `../riscv-asm` | 指令编码表（每条指令 = 操作数 → 指令字），含全部位域检查 | encode |
| `../riscv-help` | `li` / `la` / 远分支 / 远跳转的展开器，和 `li-size` / `fits-auipc-pair?` 这类判据 | layout（尺寸/判据）、encode（展开） |

## 2. 词汇边界（每层只关心自己）

每层只处理**与自己设计的那几种 s-exp** 相关的逻辑，其余一律是**不透明载荷**。

| 层 | 自己认识的 item | 其余怎么办 |
| --- | --- | --- |
| expand-data | rich 数据（`b8/b16/b32/b64`、`bN-array`、`utf-string`、`label`、`bytes`、`fill`、`align`） | 不认识就 `error`（它是数据入口） |
| flatten | `module` / `provide` / `require`（含 `prefix-in` / `rename-in` / `rename-out`）、`label` 链 | 透传（不认识任何助记符） |
| expand-pseudo | 替换表里的伪指令名 | 透传（原子 / `quote` 当数据） |
| analyze / dce | 控制流助记符、`label`、块/流结构 | 普通指令：不透明 |
| layout | 数据 `label` / `bytes` / `fill` / `pad` / `value` / `align`；控制形式的目标位与尺寸 | **不透明代码：4 字节**（`c.*` 2 字节） |
| relax | `needs-far` 提到的那些 control 形式 | 其余 item 不碰 |
| encode | 助记符 + 操作数文法（含 `.aq`/`.rl` 后缀）、目标端序、**填充策略** | 交给 `riscv-asm` 编码 |

**产物词汇也可以写在源码里 —— 含义是"请求"，不是"事实"**：

| 词汇 | 产物侧（事实） | 源码侧（请求） | 不写会怎样 |
| --- | --- | --- | --- |
| `(pad n)` | layout 把 `(align n)` 换算出来的 | 我要精确插 n 字节 | 写 `(align n)` 让 layout 算 |
| `(branch-far cond a b L)` | relax 自动选的档 | 这条转移**固定 8 字节** | 写普通分支，够不着时 relax 自动升 |
| `(branch-indirect s cond a b L)` | relax 自动选的档 | **我自己给 scratch** | 没人能给 → 编不出来 |
| `(jump-far link s L)` | relax 自动选的档 | 同上 | 同上 |
| `(链)` / `(+ …)` / `(- …)` | expand-data 原样透传的地址表达式 | 我写一个地址/差值 | — |

推论：

- **layout 的兜底 `4 字节 / 'code` 是设计，不是漏检**：真实指令在它眼里就是不透明字节串。
- **反过来，谁输出了别人的词汇就是 bug**：expand-data 不输出 `b16`（下游不认识），它输出 `(value 2 v)`。
- 一个名字只能有一个归属：`fill` / `pad` 归 layout（填充与对齐是它的模型），expand-data 只是生产者；
  `value` 的宽度归 layout 量，值归 encode 解释。

## 3. 跨层铁律

1. **寄存器一律显式**。远形式写 `(branch-far <cond> a b L)` / `(branch-indirect s <cond> a b L)`；
   没有 `call-far`（它就是 `(jump-far ra L)`）。谁都不许从助记符里猜寄存器。
   可选 scratch 的位置只有一条规则：**紧跟"写结果"的那个寄存器；没有就放最前** ——
   `(la rd tmp 链)`、`(jump-far link s L)`、`(branch-indirect s cond a b L)`。
2. **一个东西只有一种写法**。`.aq` / `.rl` / `.aqrl` 只认规范顺序；`x0` / `zero` / `0` 由
   `riscv-help` 的寄存器表统一。
3. **尺寸：谁的 item 谁负责**。`li` 由常量精确算，`la` 近形式固定 8，
   远形式 / 空槽要 scratch → 留给未实现的那一层。数据 `value` 的宽度由作者写死。
4. **目标事实只出现一次**：顶层的 `target.rkt`（XLEN + 端序 + 扩展集）。
   layout 要 XLEN（`li` 展开长度、auipc 判据），encode 要端序；expand-data 只管宽度和值。
5. **问题分三级**：本层模型错误（硬）、范围问题（`needs-far` / `value-out-of-range`）、
   交接给下一层（`needs-far` → relax，`scratch-hole` → 未实现的寄存器层）。
6. **松弛只增不减**：relax 每轮只把 item 变长，所以"太远"的集合单调递增，必然收敛。
7. **不造 label**：relax 不造新 label，所以 `place` 行永远有效，`fallthrough` 不会被松弛剪断。
8. **中间层不写合法性检查**：拼写、操作数个数、立即数范围、code 段对齐是否合法，
   都属于 encode（实际是 `riscv-asm`）。flatten–relax 只判自己模型里的东西。
9. **label 链是身份**：`(label a f)` 是一个位置多个名字；跳转目标是链；`place` 按精确链匹配。
10. **模块边界只由 provide/require 决定**：默认私有，跨模块引用必须 require，
    写全名不是后门；`provide`/`require` 可以成环（只是名字解析，没有初始化顺序）。
11. **地址表达式是一个很小的算术语言**：整数 | `(链)` | `(+ a b …)` | `(- a b …)`（≥2 个操作数，可嵌套）。
    裸链就是"取这个 label 的地址"，和 `(la rd (f))` 一致；不再有 `label-ref` / `label-diff`
    这类专用 tag，也没有"加数写成负数"的契约。
    求值在 layout（它持有符号表）：数据 label 排完就定，代码 label 要等 relax 收敛。
12. **层间只传 plain list 或 `struct program`**；入口宽容接受 `(quote …)` / `(begin …)`，
    出口一律 plain list。
13. **产物词汇可写，但那是"请求"**：`pad` / 远形式 / `ref` 都能写在源码里，
    意思是"我要这个"，而不是"已经算好了"；不写就是**让机器决定**
    （`align` 由 layout 换算、够不着的分支由 relax 升档）。
14. **请求变事实**：谁算得出来，谁就把结果写死，别把"要求"往下传。
    `(align n)` → `(pad 字节数)`（layout；`pad` 本身也可直接写在源码里，
    表示与地址无关的"精确插 n 字节"）、`label` → `(offset k …)`（layout）、
    `(value w 值)` → 字节（encode）、`li`/`la` → 指令（encode）。

## 4. IO 形状速查

| 形状 | 例子 |
| --- | --- |
| 程序/数据（扁平 item） | `((label prog1 main) (lwu t0 sp 8) (bge t1 t0 (prog1 done)))` |
| 块 + 流 | `((blocks (block ((prog1 main)) (lwu …) (bge …)) …) (flows (flow (succ 1 3) (fallthrough 1) (root? #t)) …))` |
| layout 输入 | `((segments (segment (name prog1) (kind code) (start #x100000) (end #x100FFF) (align 16)) …) (place prog1 (prog1 main) …))` |
| layout 产物 | `((segments (segment (name prog1) (kind code) (start …) (end …) (align …) (items (offset 0 (lwu …)) (offset 4 (pad 4)) …) (size 28)) …) (symbols …) (problems …))`；`problems` 空的时候就是 `(problems)` |
| build | `(build (segment (name prog1) (kind code) (start …) (size …) (bytes #vu8…)) …)` |

## 5. 形式归属

| 形式 | 谁定义 | 谁产生 | 谁消费 |
| --- | --- | --- | --- |
| `(module 名 item...)` | flatten（完整链 + 可见性）；expand-data 只把**数据侧**的壳递归展开、壳原样留着 | 人 | expand-data / flatten |
| `(provide …)` `(require …)` `prefix-in` `rename-in` `rename-out` | flatten（模块系统；编译期纯名字解析） | 人 | expand-data（透传）/ flatten |
| `(label 链...)` | flatten 定链 / analyze 定块头 / layout 定偏移 | flatten / layout | 全部 |
| 伪指令 `(load-32 …)` `(move …)` `(ble …)` | expand-pseudo 的表 | 人 | expand-pseudo |
| 真指令 `(lwu …)` `(bge …)` `(jalr …)` `(c.j …)` | expand-pseudo 产出；analyze 分类；layout 定尺寸；encode 编码 | expand-pseudo / 人 | analyze / dce / layout / relax / encode |
| 远形式 `(branch-far <cond> a b L)` `(branch-indirect [s] <cond> a b L)` `(jump-far link [s] L)` | layout/forms | **relax（自动选档）** / 人（要求固定尺寸，或自己给 scratch） | analyze / layout / relax / encode |
| `(li rd 常量)` | layout 量尺寸（`li-size`）、encode 展开（`li`） | 人 | analyze / layout / encode |
| `(la rd [tmp] 链)` | layout 量尺寸 + 判 `fits-auipc-pair?`、encode 展开（`load-pcrel`） | 人 | analyze / layout / encode |
| rich 数据 `b8` `b16` `bN-array` `utf-string` | expand-data | 人 | expand-data |
| `(bytes …)` `(fill n b)` `(align n)` | layout（尺寸/类别）；`fill` 归 layout，expand-data 是生产者 | expand-data / 人 | layout / encode |
| `(pad n)` | layout（`align` 换算成它；源码也可直接写"精确插 n 字节"） | layout / 人 | encode |
| `(value 宽度 值)` | expand-data 出宽度+值；layout 量尺寸 + 查地址范围；analyze 用它算 root；encode 定端序落字节 | expand-data | analyze / layout / encode |
| `(链)` / `(+ …)` / `(- …)` | `sexp.rkt` 定形状（`address-expr?`）；analyze 取其中**所有链**当取地址；layout 求值 + 查范围；encode 求值落字节 | 人 | expand-data / flatten / analyze / layout / encode |
| `(block …)` `(flow …)` `(program …)` | analyze | analyze / dce | dce / layout / relax |
| `(segments (segment (name …) (kind …) (start …) (end …) (align …)) …)` `(place 段名 链 …)` | layout | 人 | layout |
| `(offset k item)` `(symbols (symbol 链 段名 偏移 地址) …)` `(problems …)` | layout | layout | relax / encode / 人 |
| `(build …)` | encode | encode | 加载器（未做） |

## 6. 完整流水线（真实输出，由 flow 跑出来）

```racket
src  = ((label main) (move a0 a1) (ble a0 a1 (hot)) (jal x0 (end))
        (label hot) (addi a0 a0 1) (jalr x0 ra 0)
        (label end) (ld t0 sp 8))
data = (expand-data '((label g tab) (value 8 (main)) (utf-stringz "hi")))
```

默认流 `(expand-data flatten expand-pseudo analyze dce relax encode)`：

| 层 | 结果 |
| --- | --- |
| expand-pseudo | `(move a0 a1)` → `(add a0 a1 x0)`；`(ble a0 a1 (hot))` → `(bge a1 a0 (hot))` |
| analyze | `data` 让 `main` 成为 root（数据里存了它的地址） |
| dce | 没有可删的块 |
| layout/relax | 全部够得着，`problems = ()` |
| encode | 见下面两段字节 |

```
segment c start=#x100000 size=24
  100000  33 85 05 00   ; add a0,a1,x0
  100004  63 D4 A5 00   ; bge a1,a0,+8
  100008  6F 00 C0 00   ; jal x0,+12
  10000C  13 05 15 00   ; addi a0,a0,1
  100010  67 80 00 00   ; jalr x0,ra,0
  100014  83 32 81 00   ; ld t0,8(sp)
segment d start=#x200000 size=11
  200000  00 00 10 00 00 00 00 00   ; (value 8 (main)) = 0x100000
  200008  68 69 00                  ; "hi\0"
```

## 7. 测试与 demo 约定

- 每层一个 `test.rkt`（`#lang racket` + `rackunit`，末尾打印 `<层> tests: ok`），
  一个 `demo.rkt`（只出现**该层自己的**输入输出）。
- `encode/demo.rkt` 手写 layout 产物（不跑 flatten–relax）；想看整条链就看 §6。
- 测试条数：expand-data 75 / flatten 67 / expand-pseudo 119 / analyze 178 / dce 46 /
  layout 185 / relax 30 / encode 70 / flow 24。
- 层与层之间不互相调用；整条链要用 `flow` 串（`flow/demo.rkt`），或按 §6 手动串。
- 每个 demo/test 都直接 `racket <层>/test.rkt` 跑，不需要参数。
- 另有一个独立黑盒契约测试目录 `../riscv-compiler-rebuild-test/`：只 require 公开 API，
  按 `DESIGN.md` 锁定每层 s-exp 形状，并跑整条 `flow` 的字节 golden；入口是
  `racket ../riscv-compiler-rebuild-test/run.rkt`。

## 8. 已知缺口 / 未实现

| 项 | 现状 | 备注 |
| --- | --- | --- |
| 寄存器使用层（填 scratch） | **留空** | 位置：**relax 之后、encode 之前**；形状 `layout -> layout`（尺寸不变，不需要重跑 layout）；输入是两类 problem：`(scratch-hole 段 偏移 item origin)` 和 `(la-too-far 段 偏移 item 距离 origin)`；"洞"的形式是**item 少一个操作数**：`(branch-indirect <cond> a b L)` / `(jump-far x0 L)`。要选寄存器就得有活跃性，所以它还要吃 `program`（`requires '(program layout)`，`provides '(layout)`） |
| `la` 远形式（>±2GB） | 只报 `la-too-far`（带 `(code 块 项)` 定位） | 与填 scratch 同一层：`la` 远形式也要临时寄存器 |
| 真 reloc / 外部符号 | 没做 | 栈顶 / `malloc` 区要它 |
| 补 fallthrough 跳转、trampoline、块重排 | 没做 | layout 只报 `broken-fallthrough` |
| 加载器格式（`(build …)` → 文件） | 没做 | 现在只是数据结构 |
| `fence` / `fence.tso` 的操作数语法 | 没定义 | encode 报 "no operand syntax" |
| `.bss` / `ascii` 等数据指令 | 没做 | `fill` / `bytes` 够用 |
| 填充策略的"非 nop"选项（ebreak / 0xFF / trap） | 没做 | 只改 `target.rkt` 的表 |

## 9. 文档规范

每个 stage 目录下都有一个 `DESIGN.md`（`flow/` 也一样），用同一套骨架：

```
# <层> <名字>（<文件>）
> 一句话定位
## 1. 职责        —— 做 / 不做 两列
## 2. 输入 / 输出  —— s-exp 形状 + 例子
## 3. API         —— 表格
## 4. 规则        —— 编号条目，每条能落到代码
## 5. 不归本层管   —— 边界，指向归属层
## 6. 测试        —— 文件 + 条数 + 覆盖点
## 7. 已知缺口
```

改代码时按这张表同步：

| 改了 | 同步 |
| --- | --- |
| 某个 item 的名字 / 形状 | 该层 `DESIGN.md` + 本文 §5 形式归属 + 上/下层的词汇边界 |
| 尺寸或可达距离 | 该层 `DESIGN.md` 的表 + 相邻层的度量说明 |
| 新增一层 | 建目录（名字=stage 名）+ `DESIGN.md`；在 `flow/flow.rkt` 的 stage 表里登记 requires/provides；本文 §1 表加一行 |
| 换契约 | 本文 §1 表 + §3 铁律 + 相关 `DESIGN.md` |
| 修掉一个缺口 | 本文 §8 + 该层 §7 |
| 新增 API | 该层 `DESIGN.md` §3 |
| 新增跨层共享的形状/事实 | 放顶层（`sexp.rkt` / `target.rkt`），并在本文这一节登记 |
