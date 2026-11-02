# amd64 后端架构

> 本文记录跨层规则和当前实现事实。每层细节见各自的 `DESIGN.md`。

> 指令类别、前缀和字符串指令的模型见 [`amd64-asm/INSTRUCTIONS.md`](amd64-asm/INSTRUCTIONS.md)。
> 指令编码内部的分层见 [`amd64-asm/DESIGN.md`](amd64-asm/DESIGN.md)；
> 伪指令/装载/分支策略见 [`amd64-help/DESIGN.md`](amd64-help/DESIGN.md)。
> s-expression 分层、owner 和阶段契约见 [`SEXP-DESIGN.md`](SEXP-DESIGN.md)。

## 1. 共享事实层

这些模块不是 stage，任何层都可以依赖，但只能提供“事实”，不能包含某层策略：

| 模块 | 内容 |
| --- | --- |
| `amd64-asm/sexp.rkt` | 兼容 facade：shape.rkt + memory.rkt |
| `amd64-asm/shape.rkt` | form / name / path / 地址表达式 |
| `amd64-asm/memory.rkt` | amd64 内存操作数形状与解析 |
| `compiler/item.rkt` | `label` / `comment` / `bytes` / `fill` / `pad` / `align` / `value` / `reserve` / item-kind |
| `amd64-asm/insn.rkt` | 稳定 facade：`instruction-plan` / `plan-size` / `encode-plan` / `encode-instruction` |
| `amd64-asm/plan.rkt` | 统一 `resolved-plan`；special 与 generated plan 的 size/encode 入口 |
| `amd64-asm/encoding-plan.rkt` | 手写 special 的底层 plan：literal / rm-plan / size / bytes |
| `amd64-asm/operand.rkt` | 操作数解析、rm helper、立即数 wrapper、symbolic immediate 策略 |
| `amd64-asm/special.rkt` | 手写特殊 form facade；实现拆在 `special/{mov,integer,control,string,sse,system,table}.rkt` |
| `amd64-asm/insn-generic.rkt` | NASM 生成表的约束检查/选 form -> generic plan -> 纯字节生成 |
| `amd64-asm/insn-core.rkt` | 共享 ModR/M/SIB/REX/立即数范围事实 |
| `amd64-asm/ranges.rkt` | 共享整数/立即数/disp/rel 范围谓词；help 层转发 |
| `amd64-asm/generated/` | 从 NASM `insns.dat` 生成的指令数据；详见 [`amd64-asm/NASM.md`](amd64-asm/NASM.md) |
| `amd64-asm/registers.rkt` | 寄存器 class、名字、宽度、编号、REX 属性；详见 [`amd64-asm/REGISTERS.md`](amd64-asm/REGISTERS.md) |
| `amd64-asm/target.rkt` | `target-amd64`、端序字节、填充策略；详见 [`amd64-asm/TARGET.md`](amd64-asm/TARGET.md) |

`amd64-asm/insn.rkt` 同时服务 layout 和 encode，避免两边各自维护尺寸。
真实指令的通用 legacy/SSE form 来自 NASM 数据表；`insn.rkt` 只保留
无法一比一映射为 NASM row 的公共 form 和选择策略。

### 1.1 core 与可选层

`compiler/flow/core.rkt` 只包含核心汇编流水线，**不 require**
`loko-compatibility`、`amd64-elf` 或其它可选前端/镜像层。
`compiler/flow/flow.rkt` 只是 core 的兼容入口。

Loko 和 ELF 阶段在 `loko-compatibility/flow.rkt` 注册到同一个通用 stage
引擎；它们的 group（`loko` / `loko-manual` / `loko-near` / `elf`）也只在
那里存在。这样：

```text
compiler  -> amd64-asm + amd64-help
loko      -> compiler + amd64-elf + loko-compatibility
```

依赖方向是单向的：核心后端不知道 Loko，Loko 可以选择依赖核心后端。

## 2. 流水线

```text
loko-source -> loko-compat -> loko-ir
  -> loko-lower (可选)
  -> loko-image -> program-items / data-items / layout-spec
  -> expand-pseudo -> analyze -> dce
  -> relax (内部反复 layout) -> bind-labels -> encode
  -> loko-elf (可选) -> image

rich data -> expand-data -> flatten -> program-items / data-items
  -> 同一后半段
```

`layout` 是可单独选择的 stage；默认流不直接写 `layout`。
`loko-compat`（目录 `loko-compatibility/`）把旧写法变换成核心 item，并采集
`loko-ir`（sections / origin / mode / symbols / comms）。
`loko-image`（目录 `loko-compatibility/image/`）把 `loko-ir` 转成自动
`layout-spec` 和扁平 items。ELF writer 独立在 `amd64-elf/`。
`loko-lower`（目录 `loko-compatibility/lower/`）消除 `(reg N)`；它已注册为 stage，
由 Loko 流组使用，不在 rich-data 默认流里。

## 3. 层契约

| stage | requires | provides |
| --- | --- | --- |
| `loko-compat` | `loko-source` | `program-items` `data-items` `loko-aliases` `loko-ir` |
| `loko-image`（可选） | `loko-ir` | `program-items` `data-items` `layout-spec` |
| `loko-elf`（可选） | `build` `bound-layout` `loko-ir` | `image` |
| `loko-lower`（可选） | `loko-ir` | `loko-ir` |
| `expand-data` | `rich-data` | `data-items` |
| `flatten` | `program-items` `data-items` | `program-items` `data-items` `names` |
| `expand-pseudo` | `program-items` | `program-items` |
| `analyze` | `program-items` `data-items` | `program` |
| `dce` | `program` | `program` |
| `layout` | `program` `data-items` `layout-spec` | `measured-layout`（含地址求解） |
| `relax` | `program` `data-items` `layout-spec` | `measured-layout` |
| `bind-labels` | `measured-layout` | `bound-layout` |
| `encode` | `bound-layout` | `build` |

允许的跨层依赖：

- `dce -> analyze`：消费 `program` struct。
- `loko-compat -> sexp/item/registers`：只消费共享形状和寄存器事实。
- `layout -> analyze`：消费 `program` struct。
- `relax -> layout`：驱动布局。
- `flow -> 所有 stage`：组合根。

不允许：

- `layout -> encode`
- `encode -> layout`
- 任何层用全局 target；target 必须显式传参。

## 4. 伪指令 / 真实指令边界

`expand-pseudo` 之后，程序里只允许真实 form：

```text
jmp-short jmp-near
jcc-short jcc-near
call-near call-indirect
...
```

`jmp` / `jcc` / `call` / `je` / `jz` / `li` 等伪拼写必须在 `expand-pseudo` 里消失。

`li` 当前展开：

```text
整数          -> mov
地址表达式    -> RIP-relative lea
```

flow 在 `expand-pseudo` 后调用 `pseudo-leftover?`，有残留就报错。

## 5. measured / bound 边界

`layout` / `relax` 只产生：

```text
segments + anchors + requests + problems
```

没有绝对地址。

`bind-labels` 才把 anchor 变成：

```text
symbols: (symbol chain segment offset address)
```

`encode` 只接受 bound-layout；有 requests 或 problems 就拒绝出产物。

## 6. 尺寸与 relax

- 所有非控制流尺寸在 layout 前固定：
  - 立即数宽度；
  - 常量 displacement；
  - REX / ModR/M / SIB；
  - `li` 展开形式。
- 符号内存 displacement 固定为 disp32。
- 只有 `jmp-short` / `jcc-short` 允许被 relax 升成 near。
- relax 只增不减，所以收敛。
- `near` 超出 rel32 范围目前只报 `needs-far` problem。

## 7. 错误模型

| 名字 | 阶段 | 含义 |
| --- | --- | --- |
| `requests` | layout | 交给 relax 或未来寄存器层 |
| `needs-near` | layout | short 越界，relax 可消费 |
| `problems` | layout / bind / encode | 不能继续出产物 |
| `loko-problems` | loko-compat | 旧写法不能纯变换（如 `%call`、符号运算等） |
| `undefined-target` | layout | 分支目标找不到 |
| `needs-far` | layout | near 也放不下，far form 未实现（request，由 encode 拒绝） |
| `pseudo-leftover` | flow | 伪指令漏到 layout 前 |
| `unallocated-pseudo` | lower | 伪寄存器没有分配，仍留在 item 里 |
| `uncolored-pseudo` | lower | 干涉图着色时没有可用物理寄存器 |
| `comm-without-bss-section` | loko-compat | 有 `%comm` 但没有 bss section |
| `reserve-outside-hole` | layout | `reserve` 出现在 code/data 段 |
| `hole-materialized-item` | layout | hole 段里出现了要写字节的 item（bytes / fill / value / pad / 指令） |
| `unplaced-block` / `unplaced-data` / `unplaced` | layout | unit 的 label 没有任何 place 规则命中 |
| `unlabeled-run` | layout | data/flat unit 没有 label，没法定位 |
| `ambiguous-placement` | layout | 一个 unit 的 label 命中多个段 |
| `mode32-unsupported-form` | loko-image | `%mode 32` 段里的 item 不在审计子集里（见 `loko-compatibility/mode32.rkt`） |
| `value-out-of-range` | bind-labels | 解析后的 `(value 宽度 …)` 值放不进宽度 |

所有 kind 都只是符号，细节跟在后面：形状统一是 `(种类 细节 ...)`
（`compiler/problem.rkt`），所以打印/断言不需要认识某一层。

## 7.1 数据形状约定（各层共用的事实，不要各写一份）

| 形状 | 唯一来源 | 说明 |
| --- | --- | --- |
| `program`（blocks + flows） | `compiler/analyze/analyze.rkt` | `program?` / `program-of`（收 program 或 item 列表）/ `program->items`（反过来） |
| `problem` = `(种类 细节 ...)` | `compiler/problem.rkt` | layout / image / lower / loko-compat 都吐这一种；入口层决定报错还是继续 |
| `request` = `(种类 origin 段 偏移 item 距离)` | `compiler/layout/forms.rkt` | 访问器 `request-origin-block` / `request-item` …；消费方不要数 `list-ref` |
| 条件码拼写 | `amd64-asm/cc.rkt` | 规范码 + 编码顺序 + 别名 + j 前缀都在那一张表；`amd64-help/cc.rkt` 只是转发 |
| 符号表项 `(symbol 链 段 偏移 地址)` | `compiler/bind-labels/forms.rkt` | `amd64-elf/writer.rkt` 也用它，不另定义访问器 |
| 段填充 | `amd64-asm/target.rkt` 的 `padding-bytes` | code=`0x90`，data=`0`；与目标位数无关 |
| 整数 -> 字节 | `integer->bytes`（bytes）vs `u8/u16/u32/u64`（list） | 编码器内部用 list 拼接、最后 `list->bytes` 一次；`(value 宽度 …)` 直接写进缓冲 |

`program->items` 收的是"program 或 item 列表"（也认旧壳 `quote`/`begin`），
需要 program 的层用 `program-of`，别自己写 `(if (program? x) x (analyze x))`。

### 本环境的一个坑：`for/first`

这个 Racket 的 `for/first` 只返回**第一次迭代**的值，不是文档说的"第一个非 `#f`"
（实测 `(for/first ([x '(1 2 3)]) (and (= x 3) 'hit))` 给 `#f`）。要"找第一个
满足条件的"就用 `for/or`，或者给 `for/first` 配 `#:when`。见
`compiler/flatten/flatten.rkt` 的 `resolve-ref`。

## 8. 纯函数与状态

- 各层入口是纯函数；内部局部状态只用于遍历/累加。
- 不使用动态参数或全局 current-target。
- `loko-compat` 的标签/别名索引是本次调用的局部状态，不跨调用。
- `flow` 的 hash context 是组合层局部状态。
- `layout` / `relax` 不修改输入的 program/data/spec。

## 9. 当前入口

```racket
;; 核心汇编后端：不加载 Loko/ELF
(require "amd64/compiler/flow/flow.rkt")

(compile target-amd64
         (list (cons 'rich-data ...)
               (cons 'program-items ...)
               (cons 'layout-spec ...)))

;; 可选 Loko/ELF 流：只有这里加载 loko-compatibility 和 amd64-elf
(require "amd64/loko-compatibility/flow.rkt")

(compile target-amd64
         (list (cons 'loko-source ...))
         'loko-manual)
```
