# 架构总览（索引 + 规范）

> **本文件只做两件事**：给出全局地图，和写死跨层规矩。
> 每层的细节在各自的 `DESIGN.md` 里，本文件不重复。

## 0. 文档地图

| 文档 | 讲什么 |
| --- | --- |
| `ARCHITECTURE.md`（本文） | 分层地图、词汇边界、跨层铁律、IO 形状、形式归属、缺口清单、文档规范 |
| `D1/DESIGN.md` | 数据定义：宽度 / 值域 / 字符串 / 数组 / 地址字 |
| `L1/DESIGN.md` | 模块展平 + 链式查表（只做名字） |
| `L2/DESIGN.md` | 伪指令替换表 |
| `L3/DESIGN.md` | 控制流分析：块、流、root |
| `L4/DESIGN.md` | 死代码消除 |
| `L5/DESIGN.md` | 布局：放置、度量、符号表、范围检查、problems |
| `L6/DESIGN.md` | 分支松弛（只升形式） |
| `L7/DESIGN.md` | 编码：操作数顺序、端序、字节规则 |
| `../riscv-asm/README.md` | 指令编码表（生成器 + 运行时），L7 的编码来源 |
| `../riscv-help/DESIGN.md` | `li` / `la` / 远分支 / 远跳转的展开器 |

## 1. 分层总图

```
      rich 数据 ─→ D1 数据定义 ─┐
                                │
source(多输入)                  │  每层都是纯函数, 可单独测
──────────────                  ↓
program list ┐
data    list ├─ L1 展平 ─→ L2 替换 ─→ L3 分析 ─→ L4 死代码消除 ─→ L5 布局 ─→ L6 松弛 ─→ L7 编码
layout  list ┘                      program       program         (layout)     (layout)     (bytes)
```

| 层 | 文件 | 一句话 | 输入 | 输出 | 细节 |
| --- | --- | --- | --- | --- | --- |
| D1 | `D1/expand.rkt` | 数据定义 | rich 数据 | 核心 item | [`D1/DESIGN.md`](D1/DESIGN.md) |
| L1 | `L1/flatten.rkt` | 模块展平 + 链式查表 | 多输入 item | item + 名字表 | [`L1/DESIGN.md`](L1/DESIGN.md) |
| L2 | `L2/rewrite.rkt` | 伪指令替换 | item | item | [`L2/DESIGN.md`](L2/DESIGN.md) |
| L3 | `L3/insn.rkt` `L3/cfg.rkt` `L3/analyze.rkt` | 控制流分析（只分析） | item（+ 可选 data） | `program` = blocks + flows | [`L3/DESIGN.md`](L3/DESIGN.md) |
| L4 | `L4/dce.rkt` | 死代码消除（改控制流） | `program` | `program` | [`L4/DESIGN.md`](L4/DESIGN.md) |
| L5 | `L5/forms.rkt` `L5/layout.rkt` | 布局计算 | `program` + data + layout 输入 | layout | [`L5/DESIGN.md`](L5/DESIGN.md) |
| L6 | `L6/relax.rkt` | 分支松弛 | `program` + data + layout 输入 | layout | [`L6/DESIGN.md`](L6/DESIGN.md) |
| L7 | `L7/target.rkt` `L7/insn.rkt` `L7/encode.rkt` | 编码 | layout | `(build …)` | [`L7/DESIGN.md`](L7/DESIGN.md) |

两个外部包：

| 包 | 管什么 | 谁用 |
| --- | --- | --- |
| `../riscv-asm` | 指令编码表（每条指令 = 操作数 → 指令字），含全部位域检查 | L7 |
| `../riscv-help` | `li` / `la` / 远分支 / 远跳转的展开器，和 `li-size` / `fits-auipc-pair?` 这类判据 | L5（尺寸/判据）、L7（展开） |

## 2. 词汇边界（每层只关心自己）

每层只处理**与自己设计的那几种 s-exp** 相关的逻辑，其余一律是**不透明载荷**。

| 层 | 自己认识的 item | 其余怎么办 |
| --- | --- | --- |
| D1 | rich 数据（`b8/b16/b32/b64`、`bN-array`、`utf-string`、`label`、`bytes`、`fill`、`align`） | 不认识就 `error`（它是数据入口） |
| L1 | `module`、`label` 链 | 透传（不认识任何助记符） |
| L2 | 替换表里的伪指令名 | 透传（原子 / `quote` 当数据） |
| L3 / L4 | 控制流助记符、`label`、块/流结构 | 普通指令：不透明 |
| L5 | 数据 `label` / `bytes` / `fill` / `value` / `align`（输入）+ `pad`（产物）；控制形式的目标位与尺寸 | **不透明代码：4 字节**（`c.*` 2 字节） |
| L6 | `needs-far` 提到的那些 control 形式 | 其余 item 不碰 |
| L7 | 助记符 + 操作数文法（含 `.aq`/`.rl` 后缀）、目标端序、**填充策略** | 交给 `riscv-asm` 编码 |

推论：

- **L5 的兜底 `4 字节 / 'code` 是设计，不是漏检**：真实指令在它眼里就是不透明字节串。
- **反过来，谁输出了别人的词汇就是 bug**：D1 不输出 `b16`（下游不认识），它输出 `(value 2 v)`。
- 一个名字只能有一个归属：`fill` 归 L5（padding 需要它），D1 只是生产者；
  `value` 的宽度归 L5 量，值归 L7 解释。

## 3. 跨层铁律

1. **寄存器一律显式**。远形式写 `(branch-far <cond> a b L)` / `(branch-indirect s <cond> a b L)`；
   没有 `call-far`（它就是 `(jump-far ra L)`）。谁都不许从助记符里猜寄存器。
2. **一个东西只有一种写法**。`.aq` / `.rl` / `.aqrl` 只认规范顺序；`x0` / `zero` / `0` 由
   `riscv-help` 的寄存器表统一。
3. **尺寸：谁的 item 谁负责**。`li` 由常量精确算，`la` 近形式固定 8，
   远形式 / 空槽要 scratch → 留给未实现的那一层。数据 `value` 的宽度由作者写死。
4. **端序只出现一次**：`L7/target.rkt`。D1 只管宽度和值，L5 只管字节数。
5. **问题分三级**：本层模型错误（硬）、范围问题（`needs-far` / `value-out-of-range`）、
   交接给下一层（`needs-far` → L6，`scratch-hole` → 未实现的寄存器层）。
6. **松弛只增不减**：L6 每轮只把 item 变长，所以"太远"的集合单调递增，必然收敛。
7. **不造 label**：L6 不造新 label，所以 `place` 行永远有效，`fallthrough` 不会被松弛剪断。
8. **中间层不写合法性检查**：拼写、操作数个数、立即数范围、code 段对齐是否合法，
   都属于 L7（实际是 `riscv-asm`）。L1–L6 只判自己模型里的东西。
9. **label 链是身份**：`(label a f)` 是一个位置多个名字；跳转目标是链；`place` 按精确链匹配。
10. **层间只传 plain list 或 `struct program`**；入口宽容接受 `(quote …)` / `(begin …)`，
    出口一律 plain list。
11. **请求变事实**：谁算得出来，谁就把结果写死，别把"要求"往下传。
    `(align n)` → `(pad 字节数)`（L5）、`label` → `(offset k …)`（L5）、
    `(value w 值)` → 字节（L7）、`li`/`la` → 指令（L7）。

## 4. IO 形状速查

| 形状 | 例子 |
| --- | --- |
| 程序/数据（扁平 item） | `((label prog1 main) (lwu t0 sp 8) (bge t1 t0 (prog1 done)))` |
| 块 + 流 | `((blocks (block ((prog1 main)) (lwu …) (bge …)) …) (flows (flow (succ 1 3) (fallthrough 1) (root? #t)) …))` |
| layout 输入 | `((segments (segment prog1 code #x100000 #x100FFF 16) …) (place prog1 (prog1 main) …))` |
| layout 产物 | `((segments (segment (name prog1) … (items (offset 0 (lwu …)) (offset 4 (pad 4)) …) (size 28)) …) (symbols …) (problems …))` |
| build | `(build (segment (name prog1) (start …) (size …) (bytes #vu8…)) …)` |

## 5. 形式归属

| 形式 | 谁定义 | 谁产生 | 谁消费 |
| --- | --- | --- | --- |
| `(module 名 item...)` | L1 | 人 | L1 |
| `(label 链...)` | L1 定链 / L3 定块头 / L5 定偏移 | L1 / L5 | 全部 |
| 伪指令 `(load-32 …)` `(move …)` `(ble …)` | L2 的表 | 人 | L2 |
| 真指令 `(lwu …)` `(bge …)` `(jalr …)` `(c.j …)` | L2 产出；L3 分类；L5 定尺寸；L7 编码 | L2 / 人 | L3 / L4 / L5 / L6 / L7 |
| 远形式 `(branch-far <cond> a b L)` `(branch-indirect [s] <cond> a b L)` `(jump-far link [s] L)` | L5/forms | 人 / L6 | L3 / L5 / L6 / L7 |
| `(li rd 常量)` | L5 量尺寸（`li-size`）、L7 展开（`li`） | 人 | L3 / L5 / L7 |
| `(la rd [tmp] 链)` | L5 量尺寸 + 判 `fits-auipc-pair?`、L7 展开（`load-pcrel`） | 人 | L3 / L5 / L7 |
| rich 数据 `b8` `b16` `bN-array` `utf-string` | D1 | 人 | D1 |
| `(bytes …)` `(fill n b)` `(align n)` | L5（尺寸/类别）；`fill` 归 L5，D1 是生产者 | D1 / 人 | L5 / L7 |
| `(pad n)` | L5 把 `(align n)` 换算成的事实 | L5 | L7 |
| `(value 宽度 值)` | D1 出宽度+值；L5 量尺寸 + 查地址范围；L3 用它算 root；L7 定端序落字节 | D1 | L3 / L5 / L7 |
| `(label+ 链 加数)` | D1 归一；L3 当取地址；L5 解析范围；L7 落值 | 人 / D1 | L3 / L5 / L7 |
| `(block …)` `(flow …)` `(program …)` | L3 | L3 / L4 | L4 / L5 / L6 |
| `(segments …)` `(place …)` | L5 | 人 | L5 |
| `(offset k item)` `(symbols …)` `(problems …)` | L5 | L5 | L6 / L7 / 人 |
| `(build …)` | L7 | L7 | 加载器（未做） |

## 6. 完整流水线（真实输出）

```racket
src  = ((label main) (move a0 a1) (ble a0 a1 (hot)) (jal x0 (end))
        (label hot) (addi a0 a0 1) (jalr x0 ra 0)
        (label end) (ld t0 sp 8))
data = (expand-data '((label g tab) (value 8 (label+ (main) 0)) (utf-stringz "hi")))
```

| 层 | 结果 |
| --- | --- |
| L2 | `(move a0 a1)` → `(add a0 a1 x0)`；`(ble a0 a1 (hot))` → `(bge a1 a0 (hot))` |
| L3 | `data` 让 `main` 成为 root（数据里存了它的地址） |
| L4 | 没有可删的块 |
| L5/L6 | 全部够得着，`problems = ()` |
| L7 | 见下面两段字节 |

```
segment c start=#x100000 size=24
  100000  33 85 05 00   ; add a0,a1,x0
  100004  63 D4 A5 00   ; bge a1,a0,+8
  100008  6F 00 C0 00   ; jal x0,+12
  10000C  13 05 15 00   ; addi a0,a0,1
  100010  67 80 00 00   ; jalr x0,ra,0
  100014  83 32 81 00   ; ld t0,8(sp)
segment d start=#x200000 size=11
  200000  00 00 10 00 00 00 00 00   ; (value 8 (label+ (main) 0)) = 0x100000
  200008  68 69 00                  ; "hi\0"
```

## 7. 测试与 demo 约定

- 每层一个 `test.rkt`（`#lang racket` + `rackunit`，末尾打印 `<层> tests: ok`），
  一个 `demo.rkt`（只出现**该层自己的**输入输出）。
- 测试条数：D1 62 / L1 43 / L2 119 / L3 176 / L4 46 / L5 171 / L6 30 / L7 57。
- 层与层之间不互相调用；要看整条链就按顺序手动串（或看 §6）。
- 每个 demo/test 都直接 `racket <层>/test.rkt` 跑，不需要参数。

## 8. 已知缺口 / 未实现

| 项 | 现状 | 备注 |
| --- | --- | --- |
| scratch 寄存器（`scratch-hole` 的填充） | **留空** | "动态内存布局 / 寄存器使用"层，尚未设计 |
| `la` 远形式（>±2GB） | 只报 `la-too-far` | 需要 scratch |
| 真 reloc / 外部符号 | 没做 | 栈顶 / `malloc` 区要它 |
| 补 fallthrough 跳转、trampoline、块重排 | 没做 | L5 只报 `broken-fallthrough` |
| 加载器格式（`(build …)` → 文件） | 没做 | 现在只是数据结构 |
| `fence` / `fence.tso` 的操作数语法 | 没定义 | L7 报 "no operand syntax" |
| `.bss` / `ascii` 等数据指令 | 没做 | `fill` / `bytes` 够用 |
| 填充策略的"非 nop"选项（ebreak / 0xFF / trap） | 没做 | 只改 `L7/target.rkt` 的表 |

## 9. 文档规范

每个 `<层>/DESIGN.md` 用同一套骨架：

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
| 新增一层或换契约 | 本文 §1 总图 + §3 铁律（如果需要新铁律） |
| 修掉一个缺口 | 本文 §8 + 该层 §7 |
| 新增 API | 该层 `DESIGN.md` §3 |
