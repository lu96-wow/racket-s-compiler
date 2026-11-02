# 汇编器表面语法

本文记录 **`riscv-compiler` 的输入语言**：人写什么形状，流水线就收什么形状。

这里说的“表面语法”不是 `riscv-asm` 的 `riscv-opcodes` 源文件语法，也不是
GAS 的文本汇编语法。`riscv-compiler` 没有独立的词法/语法解析器，输入就是
Racket 的 s-expression：**真列表、symbol、number、string**。

相关文档：

| 文档 | 内容 |
| --- | --- |
| [`SEXP.md`](SEXP.md) | 层间 s-exp 类型速查 |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 分层地图 |
| [`flow/DESIGN.md`](flow/DESIGN.md) | 跨层硬边界 |
| `*/DESIGN.md` | 每一层具体认识哪些 form |

---

## 1. 入口：三类 seed

汇编器没有一个“源文件”对象，而是一组在途值。最外层的输入通常是：

```racket
(run-flow target default-flow
  (list (cons 'rich-data     rich-data)      ; 人写的数据定义
        (cons 'program-items program-items) ; 人写的代码 item
        (cons 'layout-spec layout-spec)))   ; 段 + place
```

也可以跳过 `expand-data`，直接给核心 `data-items`：

```racket
(list (cons 'program-items program-items)
      (cons 'data-items    data-items)
      (cons 'layout-spec   layout-spec))
```

单独跑某一层时，入口一律经过 `as-items`，所以下面这些壳都收：

```scheme
'((label main) (ret))          ; item 列表
'(label main)                  ; 单条 item
'(begin (label main) (ret))    ; begin 壳
'(quote ((label main) (ret)))  ; quote 壳
```

出口一律是 plain list；不会把 `quote` / `begin` 继续往下一层传。

---

## 2. 原子形状

```scheme
name   := symbol | string | number
chain  := (name ...)        ; 非空
```

- `name` 是 label 链的一节，可以是 symbol、string 或 number。
- `chain` 是**非空名字列表**，例如 `(main)`、`(data table)`、`(prog1 f)`。
- `(label data1 table)` 表示链 `(data1 table)`，不是两个独立的 label。
- 裸原子当单节链看只在少数层成立；**规范写法是链**，例如 `(jal x0 (end))`。

地址表达式只出现在数据值和 `la` 的地址操作数里：

```scheme
expr := integer
      | chain
      | (+ expr expr ...)    ; >= 2 个操作数
      | (- expr expr ...)    ; 第一个减后面所有，>= 2 个
```

例子：

```scheme
(d t)                        ; 链的地址
(+ (d t) 8)                  ; 地址 + 8
(- (d end) (d start))        ; 两个 label 的差
(+ (- (d end) (d start)) 4)  ; 差 + 4
```

地址表达式**不在前端求值**：`layout` / `relax` 用临时 anchor，`bind-labels`
之后才有最终绝对地址。

---

## 3. 代码 item

### 3.1 label

```scheme
(label main)
(label data table)
```

同一位置要多个名字，就连续写多条：

```scheme
(label a f)
(label a g)      ; 和上一条同位置，链 (a g) 是另一个名字
```

之后所有引用都写链：

```scheme
(jal x0 (end))
(beq a0 a1 (hot))
(la t0 (data table))
```

> 根模块里裸写 `hot` 有时也能被 layout 规范化成 `(hot)`，但它不会经过模块
> 名字解析。跨模块引用必须写链：`(jal x0 (prog1 f))`。

### 3.2 普通指令

统一形状：

```scheme
(mnemonic operand ...)
```

`mnemonic` 是 symbol；操作数按**汇编写法**排列，不是 `riscv-opcodes` 的声明顺序。
几个典型形状：

```scheme
(add   a0 a1 a2)
(addi  a0 a0 1)

(lw    t0 sp 8)       ; load:  (rd rs1 imm)
(ld    t0 sp 8)
(lbu   t0 a0 0)
(sb    t0 sp 0)       ; store: (rs2 rs1 imm) = (值 基址 偏移)
(sd    t0 sp 8)

(beq   a0 a1 (hot))   ; branch: (rs1 rs2 target)
(bne   a0 a1 (cold))
(blt   a0 a1 (hot))

(jal   x0 (end))      ; jal:  (rd target)
(jal   ra (helper))
(jalr  ra t0 0)       ; jalr: (rd rs1 imm)

(csrrw  a0 mstatus a1)   ; (rd csr rs1)
(csrrs  a0 mstatus a1)
(csrrc  a0 mstatus a1)
(csrr   a0 mstatus)      ; (rd csr)
(csrw   mstatus a1)      ; (csr rs1)
(csrrwi a0 mstatus 3)    ; (rd csr zimm5)
(csrwi  mstatus 3)       ; (csr zimm5)

(fence rw rw)            ; (pred succ)
(fence)                  ; 完整 fence 别名 = fence iorw, iorw
(fence.i)
(fence.tso)
(pause)

(amoadd.d.aqrl a0 a2 a1) ; (rd rs2 rs1)，aq/rl 只来自助记符后缀
```

寄存器可写：

```scheme
0 .. 31
x0 .. x31
zero ra sp gp tp t0..t6 s0..s11 a0..a7 fp
```

CSR 可以写名字（如 `mstatus`）或 `0..4095` 的整数。

当前 `operand-kind` 只覆盖：

```text
GPR / 普通整数
CSR 名或编号
zimm5（5 位无符号立即数）
```

FPR、向量寄存器、舍入模式等还没有表面语法；`encode/syntax/coverage.rkt`
会列出缺项。

### 3.3 伪指令

`expand-pseudo` 是表驱动替换；当前基础表包含：

```scheme
(move  rd rs)             ; 别名 mv
(nop)
(c.nop)

(load-8  rd rs1 [off])    ; 别名 l8  -> lbu
(load-16 rd rs1 [off])    ; 别名 l16 -> lhu
(load-32 rd rs1 [off])    ; 别名 l32 -> lwu
(load-64 rd rs1 [off])    ; 别名 l64 -> ld
(load-s8  rd rs1 [off])   ; 别名 ls8  -> lb
(load-s16 rd rs1 [off])   ; 别名 ls16 -> lh
(load-s32 rd rs1 [off])   ; 别名 ls32 -> lw

(store-8  rs2 rs1 [off])  ; 别名 st8  -> sb
(store-16 rs2 rs1 [off])  ; 别名 st16 -> sh
(store-32 rs2 rs1 [off])  ; 别名 st32 -> sw
(store-64 rs2 rs1 [off])  ; 别名 st64 -> sd

(ble  a b target)         ; 别名 branch-le  -> bge  b a target
(bgt  a b target)         ; 别名 branch-gt  -> blt  b a target
(bleu a b target)         ; 别名 branch-leu -> bgeu b a target
(bgtu a b target)         ; 别名 branch-gtu -> bltu b a target
```

形状不匹配时原样透传，最后由编码层报错。伪指令表不判断结果是否是合法真指令。

### 3.4 `li` / `la`

```scheme
(li rd integer)
(la rd expr)
(la rd scratch expr)
```

例子：

```scheme
(li t0 #x12345678)
(la t1 (data table))
(la t2 t3 (+ (data table) 8))
```

- `li` 的尺寸由常量精确决定，可能是 4 / 8 / 12 / 16 / … / 32 字节。
- `la` 当前只有近形式 `auipc + addi`，固定 8 字节；够不够得着由 layout 报
  `la-too-far` request，后续 pass 处理。
- `la` 的显式 scratch 在当前近形式里用不上，但形状保留。

### 3.5 远形式

以下形式通常由 `relax` 生成；也可以直接写，形状必须符合：

```scheme
(branch-far cond rs1 rs2 target)                    ; 8 字节
(branch-indirect cond rs1 rs2 target)               ; 12 字节，scratch 为空槽
(branch-indirect scratch cond rs1 rs2 target)       ; 12 字节，scratch 已填
(jump-far link target)                              ; 8 字节；link 为零寄存器时 scratch 为空槽
(jump-far link scratch target)                      ; 8 字节，scratch 已填
```

`link` 是链接寄存器（通常是 `ra` 或 `x0`）。`scratch` 必须是显式寄存器；
当前 `encode` 遇到未填的 scratch-hole 会拒绝出产物。

---

## 4. 数据 item

### 4.1 人写的 rich 形式

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
(utf-stringz "hi")        ; 末尾自动补一个 0

(align 8)
```

数组语义：

```scheme
(b32-array 4 1 2)    ; 1 2 2 2：前 k 个用给定值，剩余全用最后一个值
(b8-array 0)         ; 空数组，不产生字节
```

数组的 `n` 是非负整数；`n > 0` 时至少要有一个初值，初值个数不能超过 `n`。

### 4.2 核心数据 item

`expand-data` 的输出（也可以直接作为 `data-items` 输入）：

```scheme
(label chain ...)
(value width expr)       ; width = 1 | 2 | 4 | 8
(bytes b ...)            ; 每个 b 是 0..255
(fill n b)               ; b 重复 n 次
(pad n)                  ; 精确补 n 字节
(align n)                ; 对齐请求；n 是正整数
(reserve n)              ; 只占位置，不产生文件字节；只允许在 hole 段
```

`value` 的值可以是整数或地址表达式：

```scheme
(value 8 (main))
(value 8 (+ (d t) 8))
(value 8 (- (d end) (d start)))
```

整数的值域按宽度检查：`v ∈ [-2^(8w-1), 2^(8w))`，按补码取低 `8w` 位。
字符串按 UTF-8 编码；`utf-stringz` 额外补一个 0 字节。

---

## 5. 模块、provide、require

模块只影响名字，不影响指令、尺寸或地址：

```scheme
(module m
  (provide f)                                  ; 导出本地链 (f)
  (provide (rename-out ((f fn))))              ; 本地 (f) 导出为外部 (fn)
  (provide *)                                  ; 导出本模块直接定义的 label

  (require data)                               ; 拉入 data 模块
  (require (prefix-in d: data))                ; 绑定成 d:名字
  (require (rename-in data ((table tbl))))     ; 外部 (table) -> 本地 (tbl)

  (label f)
  ...)
```

配对顺序要记清：

```scheme
(rename-out (本地链 外部链) ...)
(rename-in  外部链 (外部链 本地链) ...)
```

规则：

- 默认私有；没有 `provide` 的 label，模块外引用不到。
- label 在声明它的模块及其子模块里可见，内层遮蔽外层。
- `require` 绑定在本模块及其子模块里可见。
- 循环 `require` 允许；这里只是名字解析，没有初始化顺序。
- 同名冲突报错。
- `provide` 可以 re-export 通过 `require` 进来的名字。
- 模块解析完成后，所有 label 和引用都是完整链，之后的层看不到模块。

引用写链：

```scheme
(module prog
  (require data)
  (label main)
  (la t0 (table))
  (jal ra (helper)))
```

---

## 6. 段与 place：layout spec

代码里**没有** `.text` / `.data` / `.section` 这种指令。段归属单独写在 layout spec：

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

- `start` 可以省略；省略时由 layout 从 spec 的 `(origin …)` 起按 `align` 求解。
  `(origin n)` 可写多次，取第一条；缺省为 0。
- `end` / `size` 至少给一个，表示容量约束。
- `align` 是对齐约束，必须给且为正整数。
- `place` 按**精确链**匹配块头或数据游程的 label。
- 代码段里没有 section 概念，块去哪一段只由 `place` 决定。

三种段 kind：

| kind | 收的 item | `(align n)` 的产物 | 文件字节 |
| --- | --- | --- | --- |
| `code` | `label` / `align` / `pad` / 指令 | `(pad n)`，填 `nop` | 有 |
| `data` | `label` / `align` / `pad` / `bytes` / `fill` / `value` | `(pad n)`，填 0 | 有 |
| `hole` | `label` / `align` / `reserve` | `(reserve n)` | **没有** |

`hole` 段只回答“这些地址存在”；内容由加载器 / 程序 / 硬件定义，`build`
里它的 `bytes` 是空字节串，`size` 照旧。

---

## 7. 尺寸与合法性速查

| form | 尺寸 | 备注 |
| --- | --- | --- |
| `label` | 0 | 不占字节 |
| `align` | 由游标决定 | 产物是 `pad` 或 `reserve` |
| `pad n` | `n` | code / data 收 |
| `bytes ...` | 元素个数 | data 收 |
| `fill n b` | `n` | data 收 |
| `value w v` | `w` | data 收 |
| `reserve n` | `n` | 只占位置，hole 收 |
| `c.*` 真指令 | 2 | 压缩指令 |
| 普通真指令 | 4 | 当前实现的不透明兜底 |
| `li` | 4 / 8 / 12 / … / 32 | 由常量决定 |
| `la` | 8 | 当前近形式 |
| `branch-far` | 8 | 反向分支 + `jal` |
| `branch-indirect` | 12 | 反向分支 + `auipc + jalr` |
| `jump-far` | 8 | `auipc + jalr` |

控制转移的目标写在最后一个操作数；`encode` 把它换成相对当前 item 的偏移。
地址表达式和 `value` 的最终宽度由 `bind-labels` / `encode` 检查。

---

## 8. 完整例子

### 8.1 最小程序 + 数据 + 布局

```scheme
;; 代码
(define program-items
  '((label main)
    (li t0 42)
    (move a0 t0)
    (ble a0 a1 (hot))
    (jal x0 (end))
    (label hot)
    (ld t0 sp 8)
    (jalr x0 ra 0)
    (label end)))

;; 数据
(define rich-data
  '((label d table)
    (b64 (main))
    (utf-stringz "hi")))

;; 布局
(define layout-spec
  '((segments
     (segment (name c) (kind code) (start #x100000) (end #x100FFF) (align 16))
     (segment (name d) (kind data) (start #x200000) (end #x200FFF) (align 8)))
    (place c (main) (hot) (end))
    (place d (d table))))
```

### 8.2 模块

```scheme
(define prog
  '((module prog
      (provide main helper)
      (require data)
      (label main)
      (la t0 (table))
      (jal ra (helper))
      (jalr x0 ra 0)
      (label helper)
      (ret))))

(define data
  '((module data
      (provide table)
      (label table)
      (utf-stringz "hi"))))
```

`flatten` 之后，`prog` 里的 `(table)` 会变成 `(data table)`，
`prog` 里的 label 会变成 `(prog main)` / `(prog helper)`。

---

## 9. 这不是 GAS 文本汇编

不支持、也不打算在这一层支持：

```asm
.text
.globl main
main:
    addi a0, a0, 1
    ld   t0, 8(sp)
    beq  a0, a1, hot
```

对应写法是：

```scheme
((label main)
 (addi a0 a0 1)
 (ld t0 sp 8)
 (beq a0 a1 (hot)))
```

差别：

- 没有逗号、没有 `%` 寄存器前缀、没有 `8(sp)` 内存语法。
- 没有 `foo:` 文本 label，用 `(label foo)`。
- 没有 `.text` / `.data`，用 layout spec 的 `(segment ...)` / `(place ...)`。
- 没有 `.byte` / `.word`，用 `(bytes ...)` / `(b32 ...)` / `(value ...)`。
- 没有 `.align`，用 `(align n)`。
- 没有文本表达式，地址运算只有 `(+ ...)` / `(- ...)`。
- 没有重定位 / 链接器语法；符号地址由 `layout` + `bind-labels` 在内部解决。

当前还没有表面语法的操作数类别：FPR、向量寄存器、舍入模式、向量掩码等。
加这些类别时改 `encode/syntax/operand*.rkt`，不要往 `insn.rkt` 里塞特例。

---

## 10. 维护点

| 想改什么 | 改哪里 |
| --- | --- |
| form / name / chain / 地址表达式 | `sexp.rkt` |
| label、数据宽度、字符串、数组 | `expand-data/expand.rkt` |
| 伪指令拼写和展开规则 | `expand-pseudo/table*.rkt` |
| module / provide / require / 链解析 | `flatten/flatten.rkt` |
| 普通指令的操作数顺序 | `encode/syntax/order.rkt` |
| 特殊指令形式（`fence` 等） | `encode/syntax/direct.rkt` |
| 操作数种类（GPR / CSR / …） | `encode/syntax/operand*.rkt` |
| 段、place、对齐、item 合法性 | `layout/layout.rkt`、`layout/forms.rkt` |
| `li` / `la` / 远分支展开 | `../riscv-help/` |
| 指令名、宽度、位域 | `../riscv-asm/generated/` |
| target 的 XLEN / 扩展集 | `target.rkt` |

新增一种表面写法时，至少检查：

1. 形状是否在 `sexp.rkt` 里有统一的判定。
2. 是否需要改 `expand-data` / `expand-pseudo` / `flatten` / `encode/syntax` 中的某一层。
3. 尺寸契约在哪里（`layout/forms.rkt` 或对应层）。
4. 是否需要新增 `problems` / `requests`，不要静默兜底。
5. 补测试，并更新本文档和对应的 `DESIGN.md`。
