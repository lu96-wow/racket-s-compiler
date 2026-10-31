# amd64 后端架构

> 本文记录跨层规则和当前实现事实。每层细节见各自的 `DESIGN.md`。

> 指令类别、前缀和字符串指令的模型见 [`INSTRUCTIONS.md`](INSTRUCTIONS.md)。

## 1. 共享事实层

这些模块不是 stage，任何层都可以依赖，但只能提供“事实”，不能包含某层策略：

| 模块 | 内容 |
| --- | --- |
| `sexp.rkt` | form / name / path / 地址表达式 / 内存操作数 |
| `item.rkt` | `label` / `comment` / `bytes` / `fill` / `pad` / `align` / `value` / item-kind |
| `insn.rkt` | 真实指令表、前缀/字符串指令、`instruction-size`、`encode-instruction` |
| `registers.rkt` | 寄存器 class、名字、宽度、编号、REX 属性；详见 [`REGISTERS.md`](REGISTERS.md) |
| `target.rkt` | `target-amd64`、端序字节、填充策略；详见 [`TARGET.md`](TARGET.md) |

`insn.rkt` 同时服务 layout 和 encode，避免两边各自维护尺寸。

## 2. 流水线

```text
loko-source -> loko-compat -> program-items / data-items
  -> expand-pseudo -> analyze -> dce
  -> relax (内部反复 layout) -> bind-labels -> encode

rich data -> expand-data -> flatten -> program-items / data-items
  -> 同一后半段
```

`layout` 是可单独选择的 stage；默认流不直接写 `layout`。
`loko-compat` 只做旧写法到核心 item 的纯变换，不处理 image 层。

## 3. 层契约

| stage | requires | provides |
| --- | --- | --- |
| `loko-compat` | `loko-source` | `program-items` `data-items` `loko-aliases` |
| `expand-data` | `rich-data` | `data-items` |
| `flatten` | `program-items` `data-items` | `program-items` `data-items` `names` |
| `expand-pseudo` | `program-items` | `program-items` |
| `analyze` | `program-items` `data-items` | `program` |
| `dce` | `program` | `program` |
| `layout` | `program` `data-items` `layout-spec` | `measured-layout` |
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
| `loko-problems` | loko-compat | 旧写法不能纯变换（image 指令、符号位运算等） |
| `undefined-target` | layout | 分支目标找不到 |
| `needs-far` | layout | near 也放不下，far form 未实现（request，由 encode 拒绝） |
| `pseudo-leftover` | flow | 伪指令漏到 layout 前 |

## 8. 纯函数与状态

- 各层入口是纯函数；内部局部状态只用于遍历/累加。
- 不使用动态参数或全局 current-target。
- `loko-compat` 的标签/别名索引是本次调用的局部状态，不跨调用。
- `flow` 的 hash context 是组合层局部状态。
- `layout` / `relax` 不修改输入的 program/data/spec。

## 9. 当前入口

```racket
(require "amd64/flow/flow.rkt")

(compile target-amd64
         (list (cons 'rich-data ...)
               (cons 'program-items ...)
               (cons 'layout-spec ...)))
```
