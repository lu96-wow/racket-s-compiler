# lower：伪寄存器、活性、分配

> 目录：`amd64/loko-compatibility/lower/`
>
> 这是 `loko-compatibility` 内部的下一层。输入/输出仍然是 s-expression；
> 不布局、不编码、不写 image。

## 1. 作用

Loko `arch/amd64/codegen.sls` 会生成一类“还没有分配物理寄存器”的 item：

```scheme
(mov (reg 0) (mem64+ rbp -8))
(add (reg 0) (reg 1))
```

`lower` 把这些 `(reg N)` 消掉，变成后端能继续处理的普通 item：

```scheme
(mov rax (b64 (base rbp) (disp -8)))
(add rax rcx)
```

它同时提供这条链上需要的三个纯函数部分：

```text
pseudo.rkt      (reg N) 的形状、查找、替换
uses.rkt        一条指令读/写哪些伪寄存器
liveness.rkt    基本块 + 每条指令之后的 live-out
calls.rkt       调用点 save/restore 注记 -> 显式伪寄存器搬运
allocate.rkt    干涉图 -> 物理寄存器
lower.rkt       组合入口
```

## 2. 相关 s-exp

### 输入

```scheme
(program-items item ...)
```

item 是 `loko-compat` / `expand-pseudo` 之后的普通程序 item。伪寄存器只以
`(reg N)` 出现，`N` 是非负整数。

### 输出

```scheme
(lower-result
  (items item ...)
  (allocation (下标 . 寄存器) ...)
  (problems problem ...))
```

`problems` 里的每一项都是：

```scheme
(problem unallocated-pseudo 下标)
(problem uncolored-pseudo 下标)
```

非空 `problems` 表示还有 `(reg N)` 留在 `items` 里，调用方不能把结果
当成已经完成 lower。

### 显式分配

```scheme
(lower-program-items items
                     #:allocation (hash 0 'rax 1 'rcx))
```

这时跳过活性/分配，只做替换。适合测试，也适合以后由上层传入更聪明的
分配结果。

## 3. 每部分的设计

### 3.1 `pseudo.rkt`

- `pseudo-register?` 只认 `(reg N)`，不把普通符号 `reg` 当成伪寄存器。
- `pseudo-registers-in` 会进入内存 `disp` 表达式和嵌套 form。
- `substitute-pseudo-registers` 保持没有分配的 `(reg N)` 原样，并返回缺失
  下标表；是否把缺失当错误由调用方决定。
- allocation 接受 hash 或 alist，避免层与层之间绑定到一种容器。

### 3.2 `uses.rkt`

一条指令的 uses/sets 是 lower 自己的分析，不依赖编码器：

| 形式 | uses | sets |
| --- | --- | --- |
| `(mov dst src)` | `src` + `dst` 地址里的伪寄存器 | `dst` 直接伪寄存器 |
| `(lea dst src)` | `src` 地址 | `dst` |
| `(add dst src)` | `dst` + `src` | `dst` |
| `(cmp a b)` / `(test a b)` | `a` + `b` | 无 |
| `(inc x)` / `(neg x)` | `x` | `x` |
| `(push x)` | `x` | 无 |
| `(pop x)` | `x` 地址 | `x` |
| `(call ...)` | 操作数（含间接目标） | 无 |
| 不认识的 head | 所有操作数 | 直接伪寄存器 |

“直接伪寄存器”和“地址里的伪寄存器”分开，是为了让 `(mov (reg 0) ...)`
是纯写；否则 `reg 0` 会永远活着，分配器无法复用寄存器。

### 3.3 `liveness.rkt`

- 复用 `compiler/analyze` 的基本块和 flows，不另造 CFG。
- `compute-liveness` 接受 program 或 item 列表。
- 迭代到 live-in/live-out 不动点。
- 同时保存每条指令之后的 live-out，供分配器建干涉图。
- 不模拟调用约定：`call` 本身不定义伪寄存器，所以跨调用的值仍然 live。

### 3.4 `calls.rkt`

Loko codegen 用注释表示调用点要保存哪些伪寄存器：

```scheme
(comment save-live-registers)
... call ...
(comment liveness-information)
(comment restore-live-registers)
```

`calls.rkt` 把它展开成：

```scheme
(mov (reg fresh) (reg live)) ...
... call ...
(mov (reg live) (reg fresh)) ...
```

- `fresh` 从当前最大伪下标之后开始编号。
- `save` 时保存的集合就是该位置的 live-out。
- 嵌套 save/restore 用栈匹配。
- 缺少 restore / 缺少 save 都变成 `problems`。
- `call-crossing-pseudos` 单独给出“跨调用仍 live”的下标表，供后续
  spill/分配层使用。

展开后，原始值可以在调用中被打坏；真正需要跨调用存活的是 `fresh` 副本。
但本层不决定 `fresh` 放在哪里，所以它仍然需要后续分配/溢出。

### 3.5 `allocate.rkt`

- 建干涉图：
  - 块入口同时 live 的值互相干涉；
  - 每条指令的 def 与 live-out 干涉；
  - 同一指令的多个 def 互相干涉。
- 按度数从高到低贪心着色；颜色顺序就是 `available` 顺序，结果确定。
- 允许不重叠的伪寄存器复用同一个物理寄存器。
- 不做 coalescing、不做 spill。
- 默认 `available` 是 Loko 的 scratch 集合去掉 `%pcb`（r14）、`%closure`
  （r15）、`rsp`。这只是“可用的物理寄存器”，**不是跨调用安全集合**。
- `preserved-registers` 是 Loko 的 `(rbx rbp)`；需要保守时只传这两个。

## 4. 调用约定边界

`calls.rkt` 会展开调用点的保存/恢复，但还没有解决“保存副本放在哪里”：

- 对于**不跨调用**的伪寄存器，图着色结果直接可用。
- 对于**跨调用仍 live** 的伪寄存器（包括 save 产生的 `fresh` 副本），如果
  分配到 caller-saved 寄存器，调用仍会破坏它。
- 下一步需要把 `call-crossing-pseudos` 的值分配到 preserved 寄存器，或者
  spill 到栈。栈溢出又需要 frame allocation，所以这是后续独立的一层。

当前版本会把这种情况留给分配器；寄存器不够时明确报 `uncolored-pseudo`。
这是最重要的剩余限制，不应被隐藏。

## 5. 边界：不在这里做的事

```text
跨调用值的 preserved 分配 / spill
frame allocation / LOCALS
%origin / %section / %comm / %mode / %call
ELF / BSS / symbol table
```

这些分别属于后续 lower 子层和 image 层。`lower` 只保证：

1. 找到所有 `(reg N)`；
2. 用确定的分配替换；
3. 没有替换掉的显式报告。

## 6. 建议流水线位置

```text
loko-source
  -> loko-compat
  -> expand-pseudo       ; 先把 jmp/jcc/call 规范化，CFG 才准确
  -> loko-lower          ; 本层
  -> analyze
  -> dce
  -> relax
  -> bind-labels
  -> encode
```

`lower` 内部为了活性会临时调用 `analyze`，但不把 program 结构泄漏给调用方。

## 7. 测试

```sh
racket amd64/loko-compatibility/lower/test.rkt
```

覆盖：

- `(reg N)` 的识别/替换/缺失报告；
- uses/sets 的直接写与地址写区分；
- 基本块 live-in/live-out 和每条指令的 live-out；
- 不重叠伪寄存器复用寄存器；
- 寄存器不够时的未着色报告；
- 显式分配和自动分配两条 lower 路径；
- 调用点 save/restore 展开、fresh 编号和 unmatched 注记。

## 8. 后续

1. 把 `call-crossing-pseudos` 的值分配到 preserved 寄存器，或者 spill 到栈。
2. 处理 `%comment allocate-frame` / `frame-size` / `LOCALS`，为 spill 提供槽位。
3. 支持 coalescing，减少 `mov` 复制。
4. 把 `lower` 注册成 flow 的可选 stage，输入/输出仍是 `program-items`。
5. 用真实 Loko codegen 输出做 golden test。
