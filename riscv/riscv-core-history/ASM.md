# 汇编：纯汇编 `raw` 与内嵌 `asm`

汇编有两种完全不同的用法，不要混：

| 用法 | 形状 | 经过 virtual IR？ | 可见性 |
| --- | --- | --- | --- |
| 纯汇编函数 | `(raw (name) ...)` | 否 | 全局名，受 module 管理 |
| 内嵌汇编 | `(asm (inputs ...) (outputs ...) (code ...))` | 是，作为一个 op | 只影响当前函数 |

`raw` 的第一版规则、label、控制转移和布局边界见 [`RAW.md`](RAW.md)。

---

## 1. 纯汇编 `raw`

```scheme
(module (boot)
  (provide (start))
  (raw (start)
    (label (loop))
    (addi (native x10) (native x0) 1)
    (bne (loop) (native x10) (native x11))
    (j (start))))
```

规则：

- `(raw (start) ...)` 的 `(start)` 是全局名，也是入口 label。
- body 是**已有的 native 汇编 item**：label、物理寄存器指令、`j` / `b` 等。
- 寄存器统一写 `(native xN)`；`raw` 也不引入 C ABI 别名。
- `raw` 不经过 virtual IR、allocation、materialize。
- label 仍然是全局名；module 的 `provide` / `require` 照常适用。
- `raw` 可以包含 `j` / `b`，因为它本来就是 machine 层；layout 仍然可以物化/松弛这些边。
- `raw` 是纯汇编程序的入口，不需要单独的“汇编 module”形状。
- `raw` 也是一个封闭的 machine 单元；它的局部 label 和分支按 raw 自己的规则
  处理，不进入 virtual IR 的函数 CFG。
- 当前实现：所有非 label item 固定 4 字节；控制转移目标必须在本 raw 内；
  program-layout 把 raw 名字和内部 label 加入全局地址表。

module 形状、`provide`、`require`、多文件规则见 [`MODULES.md`](MODULES.md)。

---

## 2. 内嵌汇编 `asm`

`asm` 是函数里的一个 op。它把一段 machine 代码嵌入 virtual IR，但边界必须显式：

```scheme
(block b0
  (asm
    (inputs
      (($ a) (native x10))
      (($ b) (native x11)))
    (outputs
      (($ r) (native x12)))
    (clobber
      (native x5))
    (code
      (label loop)
      (add (native x12) (native x10) (native x11))
      (bne loop (native x10) (native x11))))
  (term (jump b1)))
```

### 2.1 语义

- `inputs`：`vreg -> 物理寄存器` 的输入约束。
- `outputs`：`vreg -> 物理寄存器` 的输出约束。
- `clobber`：额外被破坏的物理寄存器。
- `code`：machine 层代码；局部 label 是裸 symbol，作用域只在 `code` 内。
- `asm` 是内存/调度屏障；不要跨越它重排。

### 2.2 allocation 怎么看 `asm`

allocation 把 `asm` 当成一个 op：

- uses = 所有 input vreg；
- defs = 所有 output vreg；
- clobber = 显式列出的物理寄存器。

它不分析 `code` 内部。  
因此 `code` 里不能出现没有在 `inputs` / `outputs` / `clobber` 里声明的物理寄存器副作用。

### 2.3 materialize 怎么做

materialize 负责：

1. 把 input vreg 搬到指定物理寄存器；
2. 发出规范化后的 `(asm-code ...)`；
3. 把 output 物理寄存器搬回 output vreg；
4. 保证 clobber 的值不被错误地认为还活着。

规则：

- input vreg 已在目标寄存器 -> 省略 move；
- input 在 slot -> 直接 `load` 到目标寄存器；
- output 在 slot -> 直接 `store` 目标寄存器；
- 物理寄存器之间的 move 用 parallel move 排序；
- 出现环时用 scratch 打断；scratch 不能与源/目标重叠；
- output 和 input 共用 vreg 时，vreg -> 寄存器绑定必须一致；
- 两个不同 input vreg 绑到同一目标寄存器报错；
- 两个不同 output vreg 绑到同一目标寄存器报错；
- v1 中 clobber 不能与 input/output 目标重叠；
- allocation 把 asm 的 clobber 并集当作全局不可用寄存器。

当前实现：`ir/materialize.rkt`、`asm/code.rkt`；code 由
`layout/relax.rkt` / `encode/encode.rkt` 作为封闭 `asm-code` 块处理。

### 2.4 限制

- `asm` 不能跳到函数里的 block；只能使用 `code` 内部的局部 label。
- `asm` 不直接引用全局名；需要全局地址时，先在 virtual IR 里用 `addr` 得到一个 vreg，再作为 input。
- `asm` 内部不出现 `($ ...)`；它已经是 machine 层。
- `asm` 内部不出现 C ABI 约定；只看显式寄存器。
- `code` 是一个封闭的局部代码块；layout / encode 只解析它内部的 label 和分支，
  不把这些 label 接到外层函数的 CFG。

---

## 3. 后端看到什么

前端/module 解析之后：

```scheme
(func ...)     ; virtual IR，含可能的 (asm ...)
(data ...)
(raw ...)      ; machine 层，绕过 virtual IR
```

- `module` / `provide` / `require` 已经消失。
- `raw` 直接进入 machine/layout 路径。
- `asm` 留在函数里，由 allocation/materialize 处理。
- 后端不需要知道“这个函数来自哪个文件/模块”。
