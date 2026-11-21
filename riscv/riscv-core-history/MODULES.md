# 模块与多文件

## 1. module 是前端概念

`module` 只做名字解析和可见性，不应该进入后端。

```text
多文件 / module / provide / require
        │
        ▼
前端解析
        │
        ▼
resolved program
  (func ...) (data ...) (raw ...)
  所有全局名已经完整限定
        │
        ▼
virtual IR -> allocation -> machine IR -> layout -> encode
```

后端看到的程序里**没有 `module`**，也没有 `provide` / `require` / 文件名。
这样模块系统不会越权进入分配、布局、编码。

## 2. 三层名字

| 层 | 形状 | 谁管理可见性 |
| --- | --- | --- |
| 全局名 | 链，例如 `(lib f)`、`(d table)` | module 的 `provide` / `require` |
| 函数局部 | vreg `($ x)`、block `b0` | 函数作用域，模块不可见 |
| asm 局部 | inline asm 里的 `loop` | asm 块作用域，模块不可见 |

**module 只管理全局名。**

- `vregs` 不能 `provide` / `require`。
- block 名不能 `provide` / `require`。
- 跨模块的“变量”不是 vreg，而是 `data` + `addr` / `load` / `store`。
- data 的 body 形状见 [`DATA.md`](DATA.md)。
- 函数之间的值通过参数/返回值传递，不通过共享 vreg。

这条规则保证寄存器分配永远只在一个函数内工作，不会出现跨模块的 liveness。

## 3. module 形状

```scheme
(module (lib util)
  (provide
    (f)
    (table)
    (start))

  (require
    (lib base)
    (prefix-in b (lib base))
    (rename-in (lib base) ((old) (new))))

  (func (f)
    ...)

  (data (table)
    ...)

  (raw (start)
    ...))
```

- `module` 名是全局链。
- `provide` / `require` 的形状沿用现有汇编层：
  - `(provide 链 ...)`
  - `(provide (rename-out ((本地链 外部链) ...)))`
  - `(provide *)`：导出本模块直接定义的全部全局名，包括 `raw` 内部 label。
  - `(require 模块链)`
  - `(require (prefix-in p 模块链))`：前缀是链头，不做字符串拼接
  - `(require (rename-in 模块链 ((外部链 本地链) ...)))`：导入目标全部导出，只改列出的外部名
- `provide` 可以 re-export 一个 `require` 进来的名字。
- `rename-in` / `rename-out` 都只收一个 pair 列表，不写成多个散开的 pair。
- `prefix-in` 的 `p` 是**链头**：导入 `(f)` 得到本地 `(p f)`，不是 `p:f`
  字符串拼接。这是和现有汇编层 `p:` 写法的一处有意差异。
- 默认私有；没有 `provide` 的全局名，模块外引用不到。
- `func` / `data` / `raw` 的名字都是全局名。
- `raw` 内部的 `label` 也是全局名；只有被 `provide` 的才会导出。

第一版只支持顶层 module；嵌套 module 以后可以作为前端 sugar 加，不影响核心 IR。

## 4. 隐式根模块

为了让单文件示例和小测试简单，顶层可以直接写：

```scheme
(func (main) ...)
(data (d table) ...)
(raw (start) ...)
```

这些 form 属于一个**隐式根模块**，所有全局名默认导出。

一旦使用显式 `(module ...)`，可见性按 `provide` / `require` 规则走。
一个文件要么全用显式 module，要么全用隐式根 form；不要混。

## 5. 解析结果

前端把：

```scheme
(module (lib)
  (provide (f))
  (func (f) ...))

(module (app)
  (require (lib))
  (func (main)
    (call ($ r) (global (f)))))
```

解析成：

```scheme
(func (lib f) ...)

(func (app main)
  (call ($ r) (global (lib f))))
```

后端只看到完整链，不知道模块边界。

## 6. 多文件

- 驱动器读入多个文件。
- 每个文件可以包含一个或多个顶层 `(module ...)`，或只包含隐式根 form。
- 一个 module 必须完整地落在一个文件里；不跨文件拆分。
- `require` 按 module 名解析，不按文件路径解析。
- 驱动器建 module 表；缺 module 或重复 module 在**前端**报错。
- 当前做**全程序编译**：所有 module 解析完后一起交给后端，地址一次算完。
- 以后如果要做分离编译，再引入 export/import 表和 link；核心 IR 不变。

文件名、搜索路径、`require` 的物理位置都不进入核心 IR。

## 7. 汇编的两种位置

### 7.1 纯汇编：`raw`

`raw` 是一个全局名 + 已有的 native 汇编 body：

```scheme
(raw (start)
  (label (loop))
  (addi (native x10) (native x0) 1)
  (bne (loop) (native x10) (native x11)))
```

- `raw` 不经过 virtual IR / allocation / materialize。
- 它本来就是 machine 层：可以用 `(native xN)`、`label`、`j` / `b`。
- 它的 label 仍然是全局名，受 module 可见性管理。
- `raw` 是纯汇编程序的入口；不需要单独的“汇编 module”形状。

### 7.2 内嵌汇编：`asm`

`asm` 是函数里的一个 op，有显式输入/输出/clobber：

```scheme
(asm
  (inputs (($ a) (native x10))
          (($ b) (native x11)))
  (outputs (($ r) (native x12)))
  (clobber (native x5))
  (code
    (label loop)
    (add (native x12) (native x10) (native x11))
    (bne loop (native x10) (native x11))))
```

- `inputs` / `outputs` 是 vreg 到物理寄存器的**约束**。
- `clobber` 是额外破坏的物理寄存器集合。
- `code` 内部是 machine 层；局部 label 是裸 symbol，作用域只在 `code` 内。
- allocation 把 `asm` 当成一个 op：使用 inputs、定义 outputs、破坏 clobber。
- materialize 负责在 `asm` 前后插入必要的 move。
- `asm` 是内存/调度屏障；不要跨越它重排。

`asm` 不允许跳到函数里的 block；复杂控制流用 block / term 表达。
`asm` 也不直接引用全局名；需要地址时，先把地址放进一个 input vreg。

## 8. 后端边界

后端输入：

```scheme
(func ...)
(data ...)
(raw ...)      ; 如果 raw 保留到 machine 层
```

后端**不处理**：

- `module`
- `provide` / `require`
- 文件名 / 搜索路径
- 全局名可见性
- vreg 可见性
- C ABI

inline asm 的输入输出搬移由 materialize 负责；module 前端不碰。

一句话：**module 在前端消失，vreg 在函数内消失，`j` / `b` 在 layout 后出现。**
