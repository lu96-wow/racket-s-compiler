# 汇编器表面语法

本文记录 **`riscv-compiler` 的输入语言**：人写什么形状，流水线就收什么形状。

这里说的“表面语法”不是 `riscv-asm` 的 `riscv-opcodes` 源文件语法，也不是
GAS 的文本汇编语法。`riscv-compiler` 没有独立的词法/语法解析器，
输入就是 Racket 的 s-expression：**真列表、symbol、number、string**。

核心约定：

> **默认/base 是 `riscv-opcodes` native 顺序；GAS 是可选的前端重写层。**

相关文档：

| 文档 | 内容 |
| --- | --- |
| [`SEXP.md`](SEXP.md) | 层间 s-exp 类型速查 |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 分层地图 |
| [`gas-syntax/DESIGN.md`](gas-syntax/DESIGN.md) | 可选 GAS 方言 |
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
'((label main) (jalr x0 ra 0))          ; item 列表
'(label main)                  ; 单条 item
'(begin (label main) (jalr x0 ra 0))    ; begin 壳
'(quote ((label main) (jalr x0 ra 0)))  ; quote 壳
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

## 3. 默认语法：native

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
(beq (hot) a0 a1)
(la t0 (data table))
```

跨模块引用必须写完整链：`(jal x0 (prog1 f))`。

### 3.2 普通指令

统一形状：

```scheme
(mnemonic operand ...)
```

默认操作数顺序 = `instruction-info-operands` 的顺序，去掉 `aq` / `rl`。
几个典型形状：

```scheme
(add   a0 a1 a2)
(addi  a0 a0 1)

(lw    t0 sp 8)       ; load:  (rd rs1 imm12)
(ld    t0 sp 8)
(lbu   t0 a0 0)
(sb    8 sp t0)       ; store: (simm12 rs1 rs2)
(sd    8 sp t0)

(beq   (hot) a0 a1)   ; branch: (bimm12 rs1 rs2)
(bne   (cold) a0 a1)
(blt   (hot) a0 a1)

(ble   (hot) a0 a1)   ; pseudo: (bimm12 rs2 rs1)
(bgt   (hot) a1 a0)
(beqz  (hot) a0)      ; pseudo: (bimm12 rs1)
(bnez  (cold) a0)

(jal   x0 (end))      ; jal:  (rd jimm20)
(jal   ra (helper))
(j     (end))         ; pseudo: (jimm20)
(jalr  ra t0 0)       ; jalr: (rd rs1 imm12)
(jr    t0)            ; pseudo: (rs1)
(jalr x0 ra 0)                 ; 显式返回，不用 ABI 伪指令 ret

> `ret` 是 ABI 伪指令（隐含 `ra` 和 C 返回约定），不属于 core 表面语法；
> 需要返回时写显式的 `(jalr x0 ra 0)`。编码层会拒绝 `ret`。

(csrrw  a0 a1 mstatus)   ; (rd rs1 csr)
(csrrs  a0 a1 mstatus)
(csrrc  a0 a1 mstatus)
(csrr   a0 mstatus)      ; (rd csr)
(csrw   mstatus a1)      ; (csr rs1)
(csrrwi a0 mstatus 3)    ; (rd csr zimm5)
(csrwi  mstatus 3)       ; (csr zimm5)

(fence rw rw)            ; (pred succ)
(fence)                  ; 完整 fence 别名 = fence iorw, iorw
(fence.i)
(fence.tso)
(pause)

(amoadd.d.aqrl a0 a1 a2) ; (rd rs1 rs2)，aq/rl 只来自助记符后缀
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
zimm5（5 位无符号整数）
```

FPR、向量寄存器、舍入模式等还没有表面语法；`encode/syntax/coverage.rkt`
会列出缺项。

### 3.3 控制转移的目标位置

native 分支的目标**不固定在最后**：

```scheme
(beq (hot) a0 a1)     ; 目标在第一个操作数
(ble (hot) a0 a1)     ; 目标在第一个操作数
(c.beqz a0 (hot))     ; 压缩分支目标在第二个操作数
(jal ra (helper))     ; 目标在第二个操作数
(j (end))             ; 目标在第一个操作数
```

`analyze` / `layout` / `relax` / `encode` 使用
`analyze/insn.rkt` 的 `jump-target` / `jump-target-position`，
不再假设 `last`。

### 3.4 可选便利别名

默认流不包含 `expand-pseudo`。需要这些别名时再加：

```scheme
(move  rd rs)             ; 别名 mv -> add rd rs x0

(load-8  rd rs1 [off])    ; 别名 l8  -> lbu
(load-16 rd rs1 [off])    ; 别名 l16 -> lhu
(load-32 rd rs1 [off])    ; 别名 l32 -> lwu
(load-64 rd rs1 [off])    ; 别名 l64 -> ld
(load-s8  rd rs1 [off])   ; 别名 ls8  -> lb
(load-s16 rd rs1 [off])   ; 别名 ls16 -> lh
(load-s32 rd rs1 [off])   ; 别名 ls32 -> lw

(store-8  off rs1 rs2)    ; 别名 st8  -> sb
(store-16 off rs1 rs2)    ; 别名 st16 -> sh
(store-32 off rs1 rs2)    ; 别名 st32 -> sw
(store-64 off rs1 rs2)    ; 别名 st64 -> sd

(branch-le  L rs1 rs2)    ; 别名 ble  -> bge  L rs2 rs1
(branch-gt  L rs1 rs2)    ; 别名 bgt  -> blt  L rs2 rs1
(branch-leu L rs1 rs2)    ; 别名 bleu -> bgeu L rs2 rs1
(branch-gtu L rs1 rs2)    ; 别名 bgtu -> bltu L rs2 rs1

(nop)
(c.nop)
```

### 3.5 `li` / `la`

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
  `la-too-far` request。
- `la` 的显式 scratch 在当前近形式里用不上，但形状保留。

### 3.6 远形式

以下形式通常由 `relax` 生成；远形式使用自己的内部顺序，目标仍在最后：

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

## 4. 可选语法：GAS

GAS 顺序不是默认语法。选择它时，在流里加 `gas-syntax`：

```racket
'(expand-data flatten gas-syntax analyze dce relax bind-labels encode)
```

它会在 `analyze` 之前把 GAS 形状改写成 native：

```scheme
(sw t0 sp 8)             -> (sw 8 sp t0)
(beq a0 a1 (L))          -> (beq (L) a0 a1)
(csrrw a0 mstatus a1)    -> (csrrw a0 a1 mstatus)
(amoadd.d.aqrl a0 a2 a1) -> (amoadd.d.aqrl a0 a1 a2)
```

GAS 只是表替换；它不编码、不布局、不绑地址。默认流不包含它。

注意：**不能把 native 程序喂给 `gas-syntax`**。两者是显式选择的方言，
不做静默探测。

---

## 5. 数据 item

### 5.1 人写的 rich 形式

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

### 5.2 核心数据 item

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

## 6. 模块、provide、require

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

---

## 7. 段与 place：layout spec

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

## 8. 尺寸与合法性速查

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

控制转移的目标位置由 `jump-target-position` 决定；`encode` 在原位置把目标
换成相对偏移。地址表达式和 `value` 的最终宽度由 `bind-labels` / `encode` 检查。

---

## 9. 完整例子

### 9.1 native 最小程序

```scheme
;; 代码
(define program-items
  '((label main)
    (li t0 42)
    (mv a0 t0)
    (ble (hot) a0 a1)
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

### 9.2 GAS 写法

同一份代码选择 GAS 方言时：

```scheme
'((label main)
  (li t0 42)
  (mv a0 t0)
  (ble a0 a1 (hot))
  (jal x0 (end))
  (label hot)
  (ld t0 sp 8)
  (jalr x0 ra 0)
  (label end))
```

流里加 `gas-syntax`，`ble` / `jal` 等会先改写成 native。

---

## 10. 这不是 GAS 文本汇编

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
 (beq (hot) a0 a1))
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

## 11. 维护点

| 想改什么 | 改哪里 |
| --- | --- |
| form / name / chain / 地址表达式 | `sexp.rkt` |
| label、数据宽度、字符串、数组 | `expand-data/expand.rkt` |
| GAS 顺序表 | `gas-syntax/order-table.rkt` |
| GAS 重写入口 | `gas-syntax/rewrite.rkt` |
| 便利别名 | `expand-pseudo/table*.rkt` |
| module / provide / require / 链解析 | `flatten/flatten.rkt` |
| native 操作数计划 | `encode/syntax/native.rkt` |
| 特殊指令形式（`fence` 等） | `encode/syntax/direct.rkt` |
| 操作数种类（GPR / CSR / …） | `encode/syntax/operand*.rkt` |
| 控制转移目标位置 | `analyze/insn.rkt` |
| 段、place、对齐、item 合法性 | `layout/layout.rkt`、`layout/forms.rkt` |
| `li` / `la` / 远分支展开 | `../riscv-help/` |
| 指令名、宽度、位域 | `../riscv-asm/generated/` |
| target 的 XLEN / 扩展集 | `target.rkt` |

新增一种表面写法时，至少检查：

1. 形状是否在 `sexp.rkt` 里有统一的判定。
2. 它是 native 基础语法、可选 GAS 方言，还是便利别名？
3. 尺寸契约在哪里（`layout/forms.rkt` 或对应层）。
4. 是否需要新增 `problems` / `requests`，不要静默兜底。
5. 补测试，并更新本文档和对应的 `DESIGN.md`。
