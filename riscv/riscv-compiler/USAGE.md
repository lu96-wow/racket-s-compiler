# riscv-compiler 使用手册

本文是 `riscv-compiler` 的完整使用入口：输入语法、功能、流水线、API、产物和边界。
更细的层内规则见文末索引。

核心约定：

> **输入是 Racket s-expression；操作数顺序是 `riscv-opcodes` native 顺序。**
> 不提供 GAS 文本汇编层；后端不认 ABI，不自动选短/远形式，不做 relax。

---

## 1. 概览

### 1.1 它是什么

`riscv-compiler` 把 s-expression 形式的 RISC-V 程序、数据和布局描述变成：

- 每个段的字节；
- 符号表和 `link` 表；
- 可继续给下一份编译使用的接口元数据；
- 最终 `(program (internal ...) (external ...))` s-exp。

### 1.2 流水线

```text
rich-data + program-items
  -> expand-struct
  -> expand-data
  -> flatten
  -> lower-code        ; 前端结构：blocks + falls
  -> validate          ; 显式形式 arity/形状
  -> emit-unit
  -> layout
  -> check
  -> bind-labels
  -> encode
  -> emit-program
```

`lower-code` 是前端结构层：把扁平 item 切成块，并记录物理 fallthrough。
它不建 CFG、不做 DCE。前端也可以直接给后端一个 `code`，跳过 `lower-code`。

### 1.3 责任边界

| 谁 | 负责 |
| --- | --- |
| 前端 | 语义、CFG、可达性、DCE、块顺序、短/远形式、scratch、尺寸 |
| `lower-code` | 扁平 item -> `code(blocks + falls)` |
| `validate` | 显式形式 arity/形状 |
| `layout` | 段、对齐、偏移、anchors、fallthrough 检查 |
| `check` | 目标存在、范围、scratch 合法性、近 `la` |
| `bind-labels` | 绝对地址、`link`、`provides`、最终宽度/容量 |
| `encode` | 指令编码、端序、填充、最终字节 |

后端不做：

- 建 CFG；
- DCE；
- 自动升级短形式到远形式；
- 自动填 scratch；
- ABI 默认值（`ra` / `sp` / `t0` 等都要显式写）。

---

## 2. 快速开始

### 2.1 用 `run-flow`

```racket
#lang racket
(require "riscv-compiler/flow/flow.rkt"
         "riscv-compiler/target.rkt")

(define target target-rv64-base)

(define program-items
  '((label main)
    (li t0 42)
    (mv a0 t0)
    (jalr x0 ra 0)))

(define rich-data
  '((label d table)
    (b64 (main))
    (utf-stringz "hi")))

(define layout-spec
  '((origin #x100000)
    (segments
     (segment (name c) (kind code) (start #x100000) (end #x100FFF) (align 16))
     (segment (name d) (kind data) (start #x200000) (end #x200FFF) (align 8)))
    (place c (main))
    (place d (d table))))

(define ctx
  (run-flow target default-flow
            (list (cons 'program-items program-items)
                  (cons 'rich-data rich-data)
                  (cons 'layout-spec layout-spec))))

(define build (flow-value ctx 'build))
```

`build` 里可以取：

```scheme
(build
  (link (base B) (symbol 链 地址) ...)
  (provides 链 ...)
  (structs ...)
  (label-provides ...)
  (struct-provides ...)
  (unit ...)
  (segment (name c) (kind code) (start ...) (size ...) (bytes #vu8...))
  ...)
```

### 2.2 只跑一层

```racket
(run-stage target 'layout seeds)
(run-stage target 'encode seeds)
```

`run-stage` 只返回这一层 `provides` 的值。层组/片段用 `run-flow`：

```racket
(run-flow target 'frontend seeds)
(run-flow target 'backend context)
(run-flow target '(expand-data flatten lower-code validate) seeds)
```

### 2.3 直接给后端 `code`

如果前端已经完成切块和 fallthrough，可以只跑后端：

```racket
(define ctx
  (run-flow target
            '(lower-code validate emit-unit layout check bind-labels encode)
            (list (cons 'code code)
                  (cons 'data-items data-items)
                  (cons 'layout-spec layout-spec))))
```

`code` 形状见第 9 节。

---

## 3. 基本 s-exp 约定

```scheme
name   := symbol | string | number
chain  := (name ...)        ; 非空
form   := (head arg ...)    ; 真列表
```

- label、模块、struct 的名字都用链。
- `(label data table)` 表示链 `(data table)`，不是两个 label。
- 裸原子只在少数位置被当作单节链；规范写法一律写链：
  `(jal x0 (end))`。
- 入口经 `as-items`，接受：

```scheme
'((label main) (jalr x0 ra 0))          ; item 列表
'(label main)                            ; 单条
'(begin (label main) (jalr x0 ra 0))    ; begin 壳
'(quote ((label main) (jalr x0 ra 0)))  ; quote 壳
```

地址表达式：

```scheme
expr := integer
      | chain
      | (+ expr expr ...)    ; >= 2 个
      | (- expr expr ...)    ; 第一个减后面所有，>= 2 个
```

例子：

```scheme
(d t)
(+ (d t) 8)
(- (d end) (d start))
```

地址表达式不在前端求值；`layout` 使用临时位置，`bind-labels` 之后才有绝对地址。

---

## 4. 代码语法

### 4.1 label

```scheme
(label main)
(label data table)
```

同一位置多个名字，连续写：

```scheme
(label a f)
(label a g)      ; 同位置，另一个名字
```

引用：

```scheme
(jal x0 (end))
(beq (hot) a0 a1)
(la-pcrel t0 (data table))
```

### 4.2 普通指令

统一形状：

```scheme
(mnemonic operand ...)
```

操作数顺序 = `instruction-info-operands` 的 native 顺序，去掉 `aq` / `rl`。

```scheme
(add   a0 a1 a2)
(addi  a0 a0 1)

(lw    t0 sp 8)       ; (rd rs1 imm12)
(ld    t0 sp 8)
(sb    8 sp t0)       ; (simm12 rs1 rs2)
(sd    8 sp t0)

(beq   (hot) a0 a1)   ; (bimm12 rs1 rs2)
(bne   (cold) a0 a1)
(blt   (hot) a0 a1)

(ble   (hot) a0 a1)   ; pseudo: (bimm12 rs2 rs1)
(bgt   (hot) a1 a0)
(beqz  (hot) a0)      ; pseudo: (bimm12 rs1)
(bnez  (cold) a0)

(jal   x0 (end))      ; (rd jimm20)
(jal   ra (helper))
(j     (end))         ; pseudo
(jalr  ra t0 0)       ; (rd rs1 imm12)
(jr    t0)            ; pseudo

(csrrw  a0 a1 mstatus)
(csrrs  a0 a1 mstatus)
(csrrc  a0 a1 mstatus)
(csrr   a0 mstatus)
(csrw   mstatus a1)
(csrrwi a0 mstatus 3)
(csrwi  mstatus 3)

(fence rw rw)
(fence)               ; fence iorw, iorw
(fence.i)
(fence.tso)
(pause)

(amoadd.d.aqrl a0 a1 a2)
```

> `ret` 是 ABI 伪指令，不属于 core 语法；需要返回时写 `(jalr x0 ra 0)`。
> 编码层会拒绝 `ret`。

### 4.3 寄存器

```text
0..31
x0..x31
zero ra sp gp tp t0..t6 s0..s11 a0..a7 fp
```

CSR 可以写名字（如 `mstatus`）或 `0..4095` 的整数。

当前表面语法只覆盖：

```text
GPR / 普通整数
CSR 名或编号
zimm5
```

FPR、向量寄存器、舍入模式、向量掩码还没有表面语法。

### 4.4 控制转移的目标位置

native 分支目标不固定在最后：

```scheme
(beq (hot) a0 a1)     ; 目标在第一个操作数
(ble (hot) a0 a1)
(c.beqz a0 (hot))     ; 第二个操作数
(jal ra (helper))     ; 第二个操作数
(j (end))             ; 第一个操作数
```

`code/insn.rkt` 用 `jump-target-position` 统一决定目标位置。

### 4.5 `li`

```scheme
(li rd integer)
```

```scheme
(li t0 42)
(li t0 #x12345678)
(li t0 #x80000000)
```

尺寸由常量精确决定，可能是 4 / 8 / 12 / … / 32 字节。展开由 `riscv-help` 负责。

### 4.6 `la-pcrel`

```scheme
(la-pcrel rd expr)
```

近形式 `auipc + addi`，固定 8 字节。

```scheme
(la-pcrel t1 (data table))
(la-pcrel t1 (+ (data table) 8))
```

够不着时 `check` 报 `la-too-far`，不会自动升级。

### 4.7 `la-pcrel-li-add`

```scheme
(la-pcrel-li-add rd tmp expr)
```

显式远形式：`auipc + li + add`，`tmp` 必需。

```scheme
(la-pcrel-li-add t2 t3 (+ (data table) 8))
```

尺寸是固定上界（rv64 40 字节），实际短出来的部分由 `encode` 补 `nop`。
`tmp` 不能是 `x0`，也不能和 `rd` 重合（`bad-scratch`）。

### 4.8 显式远形式

```scheme
(branch-jal cond rs1 rs2 target)             ; 8 字节
(branch-auipc-jalr tmp cond rs1 rs2 target)  ; 12 字节
(jump-auipc-jalr link base target)           ; 8 字节
```

- `link`：链接寄存器，通常 `ra` 或 `x0`；
- `base`：`auipc` 的落点；
- `tmp` / `base` 都是必需操作数，没有空槽；
- 零寄存器作 scratch/base/tmp -> `zero-scratch`；
- `la-pcrel-li-add` 的 tmp 等于 rd -> `bad-scratch`。

普通短形式超范围 -> `out-of-range`，不自动升级。

### 4.9 压缩指令

`c.*` 助记符直接写，尺寸 2 字节：

```scheme
(c.addi a0 1)
(c.beqz a0 (hot))
(c.j (end))
(c.jal (helper))      ; RV32
```

### 4.10 不被接受的写法

```scheme
(ret)                 ; ABI 伪指令，拒绝
(jal (end))           ; 省略 link，拒绝；写 (jal x0 (end)) 或 (jal ra (end))
```

---

## 5. 数据语法

### 5.1 rich-data

```scheme
(label d table)

(b8  1)
(b16 258)
(b32 #x12345678)
(b64 -1)

(b8-array  4096 0)
(b16-array 4 1 2)
(b32-array 4 1 2 3 4)
(b64-array 2 0)

(utf-string  "abc")
(utf-stringz "hi")        ; 末尾补 0

(align 8)
```

定宽整数：

| 形式 | 输出 |
| --- | --- |
| `(b8 v)` | `(value 1 v)` |
| `(b16 v)` | `(value 2 v)` |
| `(b32 v)` | `(value 4 v)` |
| `(b64 v)` | `(value 8 v)` |

值域：`v ∈ [-2^(8w-1), 2^(8w))`。

数组语义：

```scheme
(b32-array 4 1 2)    ; 1 2 2 2
(b8-array  5 1 2)    ; 1 2 2 2 2
(b8-array  0)        ; 空
```

- `n` 是非负整数；
- `n = 0` 不能有初值；
- `n > 0` 至少一个初值；
- 初值个数不能超过 `n`；
- 剩余位置重复最后一个初值。

字符串按 UTF-8 编码；`utf-stringz` 额外补一个 0 字节。

### 5.2 核心数据 item

`expand-data` 的输出，也可以直接作为 `data-items` 输入：

```scheme
(label chain ...)
(value width expr)       ; width = 1 | 2 | 4 | 8
(bytes b ...)            ; 每个 b 是 0..255
(fill n b)               ; b 重复 n 次
(pad n)                  ; 精确补 n 字节
(align n)                ; 对齐请求，正整数
(reserve n)              ; 只占位置；只允许在 hole 段
```

`value` 的值可以是整数或地址表达式：

```scheme
(value 8 (main))
(value 8 (+ (d t) 8))
(value 8 (- (d end) (d start)))
```

整数按宽度检查，端序由 `encode` 决定（little-endian）。

### 5.3 rich-data 与核心数据的边界

- rich 名字 `b8` / `b32` / `bN-array` / `utf-string*` 在 `expand-data` 之后消失；
- `reserve` 不是 rich 形式，只作为核心 `data-items` 输入；
- `module` 壳会保留到 `flatten`。

> **数据放 `rich-data` seed，不要混进 `program-items`。**  
> `expand-data` 只展开 `rich-data`；如果 `(b32 ...)` / `(utf-stringz ...)` 出现在
> `program-items` 里，它们不会变成数据 item，而会作为不透明 code item 被布局。
> 已经展开的核心形式可以放在 `data-items` seed。

---

## 6. struct

完整规则见 [`STRUCT.md`](STRUCT.md)。这里是使用摘要。

### 6.1 定义

```scheme
(struct (point)
  (x b32)
  (y b32))

(struct (rect)
  (p point)
  (w b16)
  (h b16))
```

Struct 内部还可以写：

```scheme
(align n)     ; 内部对齐，n 是 2 的正整数次幂
(pad n)       ; 插入 n 字节空洞
```

### 6.2 类型

```text
b8 b16 b32 b64
s8 s16 s32 s64
ptr
(array n type)
另一个 struct 名
```

| 类型 | 大小 | 对齐 |
| --- | ---: | ---: |
| b8 / s8 | 1 | 1 |
| b16 / s16 | 2 | 2 |
| b32 / s32 | 4 | 4 |
| b64 / s64 | 8 | 8 |
| ptr | XLEN/8 | XLEN/8 |

### 6.3 布局规则

1. 字段按声明顺序排列；
2. 每个字段向上对齐；
3. `(align n)` 对齐当前 offset，并提高 struct 的 align；
4. `(pad n)` 插空洞，不改变 align；
5. struct 大小向上对齐到最大 align；
6. 空 struct：size 0，align 1；
7. 不支持 packed / bitfield / union。

### 6.4 静态数据

```scheme
(label d p)
(struct-data point
  (x 1)
  (y 2))
```

缺省字段补 0；字段值可以是整数或地址表达式；嵌套 struct 写成字段对；数组字段可以写 `(array ...)` 或直接写值。

### 6.5 `sizeof` / `offsetof`

```scheme
(sizeof point)        ; 8
(offsetof point y)    ; 4
```

它们是编译期整数，可以放在普通操作数位置：

```scheme
(li t0 (sizeof rect))
```

`offsetof` 只支持直接字段，不支持路径。

### 6.6 动态访问

短形式：

```scheme
(struct-load rd base point y)
(struct-store base point y rs)
(struct-address dst base rect w)
```

要求偏移在 `[-2048, 2047]`，超出报错。

远形式：

```scheme
(struct-load-far rd base rect w tmp)
(struct-store-far base rect w rs tmp)
(struct-address-far dst base rect w tmp)
```

`tmp` 不能是 `x0`，并且要避开 `base` / `rs` 的相应限制。

数组/嵌套 struct 字段用 `struct-address` 先算地址。

---

## 7. 模块、provide、require

模块只影响名字，不影响指令、尺寸或地址。

```scheme
(module m
  (provide f)
  (provide (rename-out ((f fn))))
  (provide *)

  (require data)
  (require (prefix-in d: data))
  (require (rename-in data ((table tbl))))

  (label f)
  ...)
```

配对顺序：

```scheme
(rename-out (本地链 外部链) ...)
(rename-in  外部链 (外部链 本地链) ...)
```

规则：

- 默认私有；没有 `provide` 的 label 模块外引用不到。
- label 在声明它的模块及子模块可见，内层遮蔽外层。
- `require` 绑定在本模块及子模块可见。
- 循环 `require` 允许；这里只是名字解析。
- 同名冲突报错。
- `provide` 可以 re-export `require` 进来的名字。
- flatten 之后所有 label 和引用都是完整链，后续层看不到模块。

struct 使用同一套模块子句，但和 label 是独立名字空间；`provide *` 同时导出本模块直接声明的 label 和 struct。

> 同一个 `module` 不要同时出现在 `program-items` 和 `rich-data` 里；模块声明只应有一处。
> 数据和代码需要分开时，用两个模块加 `require`，或者干脆不用模块。

---

## 8. 段与 place：layout spec

代码里没有 `.text` / `.data` / `.section`。段归属写在 layout spec：

```scheme
'((origin #x100000)
  (segments
   (segment (name c) (kind code) (start #x100000) (end #x100FFF) (align 16))
   (segment (name d) (kind data) (start #x200000) (end #x200FFF) (align 8))
   (segment (name b) (kind hole) (start #x300000) (size #x2000) (align 4096)))
  (place c (main) (hot) (end))
  (place d (d table))
  (place b (bss) (buf)))
```

段声明：

```scheme
(segment (name s)
         (kind code|data|hole)
         (align n)
         [(start a)]
         [(end e) | (size z)])
```

- `start` 可省略；省略时从 `(origin …)` 起按 `align` 求解；
- `end` / `size` 至少给一个；
- `align` 必须给且为正整数；
- `place` 按精确链匹配块头或数据游程的 label；
- 同一个 `place` 链不能命中多个段；
- 代码块在段内的顺序保持 `code` 里的顺序；
- `code` 的 `falls` 表示物理顺序必须紧挨着；`layout` 会检查，断了报 `broken-fallthrough`。

三种段：

| kind | 收的 item | `(align n)` 产物 | 文件字节 |
| --- | --- | --- | --- |
| `code` | `label` / `align` / `pad` / 指令 | `(pad n)`，填 `nop` | 有 |
| `data` | `label` / `align` / `pad` / `bytes` / `fill` / `value` | `(pad n)`，填 0 | 有 |
| `hole` | `label` / `align` / `reserve` | `(reserve n)` | **没有** |

`hole` 段只表示“这些地址存在”；`build` 里 `bytes` 为空，`size` 保留。

外部符号通过 `externs` seed 输入：

```scheme
(link (base B) (symbol 链 地址|#f) ...)
```

地址已知的参与距离判断；`#f` 表示未链接，`check` 报 `unlinked-external`。

---

## 9. `code` 契约

### 9.1 形状

```scheme
(code
  (blocks
    (block (<label-chain> ...) item ...)
    ...)
  (falls
    (fall <from-index> <to-index>)
    ...))
```

- 块身份 = 在 `blocks` 里的下标；
- 块头是 label 链列表，可以是 `()`；
- 块内可以继续有非目标 `(label ...)`；
- `falls` 只表达物理顺序 fallthrough；
- 没有 `succ` / `root?` / CFG。

### 9.2 谁产生

- `lower-code`：从扁平 `program-items` 生成；
- 前端直接 seed `code`；
- 两者都行。`lower-code` 在同时看到 `code` 和 `program-items` 时优先使用 `code`。

### 9.3 手工构造

```racket
(require "riscv-compiler/code.rkt")

(define code
  (make-code
   (list (make-block '((main))
                     '((addi a0 a0 1)
                       (beq (done) a0 a1)))
         (make-block '((done))
                     '((jalr x0 ra 0))))
   (list (make-fall 0 1))))
```

### 9.4 校验

`validate` 会检查显式控制转移的 arity/形状，例如：

- `(jal g)` 拒绝，必须写 `(jal x0 g)` 或 `(jal x1 g)`；
- `branch-jal` / `branch-auipc-jalr` / `jump-auipc-jalr` / `la-pcrel*` 的固定 arity。

---

## 10. 流水线 API

### 10.1 seed

常用 seed：

| 名字 | 内容 |
| --- | --- |
| `program-items` | 扁平程序 item |
| `rich-data` | 人写的数据定义 |
| `data-items` | 核心数据 item |
| `code` | `(code (blocks ...) (falls ...))` |
| `layout-spec` | 段 + place |
| `externs` | 上一份的 `link` 表 |
| `extern-units` | 上一份的 `unit` |
| `extern-structs` / `extern-struct-provides` | 跨单元 struct 元数据 |
| `extern-label-provides` | 跨单元 label 元数据 |

### 10.2 stage

当前 stage：

```text
load-units
expand-struct
expand-data
flatten
lower-code
validate
emit-unit
layout
check
bind-labels
encode
emit-program
```

默认流：

```scheme
'(load-units expand-struct expand-data flatten lower-code validate emit-unit
  layout check bind-labels encode emit-program)
```

层组：

```scheme
'frontend = (load-units expand-struct expand-data flatten lower-code)
'backend  = (validate emit-unit layout check bind-labels encode emit-program)
'all      = default-flow
```

### 10.3 `run-flow` / `run-stage` / `compile`

```racket
(run-flow target selector seeds-or-context)
(run-stage target stage-name seeds)
(compile target seeds)                 ; 默认流，返回 build
(flow-value context 'build)
```

`seeds-or-context` 可以是 `((名字 . 值) ...)`，也可以是上一次 `run-flow` 的 context。
片段可以串联：

```racket
(define front (run-flow target 'frontend seeds))
(define back  (run-flow target 'backend front))
```

---

## 11. 产物

### 11.1 measured-layout

```scheme
((phase measured)
 (origin 镜像基址)
 (externs ...)
 (segments (segment (name ...) (kind ...) (start ...) (end ...) (align ...)
                    (items (offset k item) ...)
                    (size n)) ...)
 (anchors (anchor 链 段名 偏移) ...)
 (problems ...))
```

只有位置，没有绝对地址。

### 11.2 bound-layout

```scheme
((phase bound)
 (origin 镜像基址)
 (segments ...)
 (anchors ...)
 (symbols (symbol 链 段名 偏移 绝对地址) ...)
 (link (base B) (symbol 链 地址) ...)
 (provides 链 ...)
 (problems ...))
```

绝对地址 = 段 `start` + 段内偏移。

### 11.3 build

```scheme
(build
  (link (base B) (symbol 链 地址) ...)
  (provides 链 ...)
  (structs (struct-def ...) ...)
  (label-provides ...)
  (struct-provides ...)
  (unit ...)
  (segment (name ...) (kind ...) (start ...) (size ...) (bytes #vu8...))
  ...)
```

- `link` / `provides` / `segment` 是最终镜像；
- `label-provides` / `struct-provides` / `structs` / `unit` 是接口元数据；
- `hole` 段 `bytes` 为空。

### 11.4 program

```scheme
(program
  (internal
    (modules (module main (base B) ...))
    (rich-data ...)
    (functions (function (链 ...) (body item ...)) ...)
    (offsets (offset 链 相对偏移) ...))
  (external
    (modules ...)
    (rich-data ...)
    (functions ...)
    (offsets ...)))
```

绝对地址 = 项目根 module 的 `base` + `offsets` 里的偏移。

---

## 12. 常见问题与 problems

`check` / `layout` / `bind-labels` 只把失败写进 `problems`，不抛异常；
`encode` 遇到非空 `problems` 会拒绝出产物。

常见 problem：

```text
undefined-target
misaligned-target
out-of-range
zero-scratch
bad-scratch
la-too-far
external-conflict
unlinked-external
misaligned-external
broken-fallthrough
unplaced-block
unmatched-place
segment-overlap
segment-overflow
value-out-of-range
```

常见错误：

```scheme
(ret)                         ; ABI 伪指令
(jal (end))                   ; 省略 link
(beq (far) a0 a0)             ; 短形式超范围，不会自动升级
(la-pcrel t0 (far))           ; 近 la 够不着，不会自动升级
(branch-auipc-jalr x0 beq a b (L)) ; scratch 不能是 x0
(struct-load t0 t1 point z)   ; 未知字段
```

---

## 13. 尺寸与范围速查

| form | 尺寸 | 说明 |
| --- | ---: | --- |
| `label` | 0 | 不占字节 |
| `align` | 由游标决定 | 产物是 `pad` 或 `reserve` |
| `pad n` | `n` | code / data |
| `bytes ...` | 元素个数 | data |
| `fill n b` | `n` | data |
| `value w v` | `w` | data |
| `reserve n` | `n` | 只占位置，hole |
| `c.*` 指令 | 2 | 压缩 |
| 普通真指令 | 4 | 当前不透明兜底 |
| `li` | 4 / 8 / 12 / … / 32 | 由常量决定 |
| `la-pcrel` | 8 | `auipc + addi` |
| `la-pcrel-li-add` | rv64 固定 40 | 短出来补 `nop` |
| `branch-jal` | 8 | 反向分支 + `jal` |
| `branch-auipc-jalr` | 12 | 反向分支 + `auipc + jalr` |
| `jump-auipc-jalr` | 8 | `auipc + jalr` |

短形式范围：

| 形式 | 范围 |
| --- | --- |
| `beq` / `bne` / `blt` / ... | ±4 KiB |
| `c.beqz` / `c.bnez` | ±256 B |
| `jal` / `j` | ±1 MiB |
| `c.j` / `c.jal` | ±2 KiB |

---

## 14. 完整例子

```racket
#lang racket
(require "riscv-compiler/flow/flow.rkt"
         "riscv-compiler/target.rkt")

(define target target-rv64-base)

(define program-items
  '((label main)
    (la-pcrel t0 (table))
    (ld t1 t0 0)
    (add a0 a0 t1)
    (jalr x0 ra 0)))

(define rich-data
  '((struct (point)
      (x b32)
      (y b32))
    (label table)
    (struct-data point (x 1) (y 2))
    (utf-stringz "ok")))

(define layout-spec
  '((origin #x100000)
    (segments
     (segment (name c) (kind code) (start #x100000) (end #x100FFF) (align 16))
     (segment (name d) (kind data) (start #x200000) (end #x200FFF) (align 8)))
    (place c (main))
    (place d (table))))

(define ctx
  (run-flow target default-flow
            (list (cons 'program-items program-items)
                  (cons 'rich-data rich-data)
                  (cons 'layout-spec layout-spec))))

(define build (flow-value ctx 'build))
(define code-seg
  (findf (lambda (x) (and (eq? (car x) 'segment)
                          (eq? (cadr (assoc 'name (cdr x))) 'c)))
         (cdr build)))
```

---

## 15. 当前边界

不支持：

- GAS 文本汇编；
- 自动短/远形式选择；
- 自动 relaxation / linker veneer；
- 自动 scratch 选择；
- ABI 默认寄存器；
- FPR / 向量寄存器 / 舍入模式表面语法；
- bitfield / union / packed / 显式字段偏移；
- 动态数组下标；
- 多层 `offsetof` 路径；
- 自动把超范围 struct 访问变成 far 形式；
- 重定位 / 链接器格式。

设计原则：

> 前端显式选择形式，后端只检查、布局、绑定和编码。  
> 尺寸在进入 `layout` 前固定；`layout` 之后不允许改 item 尺寸。

---

## 16. 文档索引

| 文档 | 内容 |
| --- | --- |
| [`SYNTAX.md`](SYNTAX.md) | 表面语法细节 |
| [`RICH-DATA.md`](RICH-DATA.md) | rich-data 完整数据语法 |
| [`STRUCT.md`](STRUCT.md) | struct 完整布局、静态数据、字段访问 |
| [`IR.md`](IR.md) | 层间 s-exp 类型 |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 分层地图与 stage |
| [`flow/DESIGN.md`](flow/DESIGN.md) | 流水线与硬边界 |
| [`CONSTRAINTS.md`](CONSTRAINTS.md) | 尺寸/布局/形式选择约束 |
| [`layout/DESIGN.md`](layout/DESIGN.md) | 段、对齐、anchors、fallthrough |
| [`check/DESIGN.md`](check/DESIGN.md) | 显式形式检查 |
| [`bind-labels/DESIGN.md`](bind-labels/DESIGN.md) | 绝对地址、link、provides |
| [`encode/DESIGN.md`](encode/DESIGN.md) | 编码、填充、显式形式展开 |
| [`DATA.md`](DATA.md) | 各层数据形状与解析入口 |
