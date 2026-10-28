# encode 编码（`encode/insn.rkt` `encode/encode.rkt`；目标事实在顶层 `target.rkt`）

> 速览（功能 / s-exp / 设计理由）：[`../SEXP.md#encode`](../SEXP.md#encode)。
>
> 最后一步：`layout -> (build …)`，每个段一坨字节。
> **端序只出现在这里**；指令编码和位域检查都在 `riscv-asm`。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| 逐 item 出字节（数据 + 代码） | 选指令 / 优化 |
| 端序、对齐补齐 | 布局（属于 layout） |
| `value` / `ref` 求值 | 松弛（属于 relax） |
| `li` / `la` / 远形式展开 | 填 scratch 空槽（未实现的那一层） |
| 断言"写出的字节数 = layout 的偏移" | 加载器格式 / ELF / 分区镜像 |
| 有 problem 就拒绝出产物 | — |

## 2. 输入 / 输出

```
layout : relax 产物（segments + symbols + problems）
  ↓
(build (segment (name s) (kind code) (start #x1000) (size 12) (bytes #vu8…)) ...)
```

## 3. API

| 文件 | API |
| --- | --- |
| `../target.rkt`（顶层共享） | `target-xlen` `target-endianness` `target-extensions` `integer->bytes` `padding-bytes`（**填充策略**） |
| `insn.rkt` | `encode-instruction` `instruction-arity` `known-instruction?` `split-aqrl` |
| `encode.rkt` | `encode-layout` |

## 4. 规则

### 4.1 编码交给 riscv-asm

`riscv-asm` 生成的 `rebuilt` 模块里，每条指令就是一个函数：

```racket
(add 10 11 12)     ; => #x00c58533   (add a0,a1,a2)
(beq 8 10 11)      ; => #x00b50463   (beq a0,a1,+8)
(c.addi 10 1)      ; => #0x0505      (c.addi a0,1)
```

位域检查也在那里（立即数范围、压缩寄存器约束、aq/rl 值域）：

```
addi a0,a1,5000  => ERROR: imm12: value 5000 out of range [-2048, 2047]
c.beqz s2,8      => ERROR: compressed-register: register number 18 out of range [8, 15]
```

所以 encode **不写**任何合法性检查。

### 4.2 操作数顺序（本层唯一的公开接口约定）

riscv-opcodes 的声明顺序（= rebuilt 函数参数顺序）不是汇编写法：
分支/存储/原子把合并后的立即数放在第一位。

```racket
(beq bimm12 rs1 rs2)      ; 函数
(beq rs1 rs2 L)           ; 我们写
```

`encode/insn.rkt` 有一张"调用位置 ← s-exp 位置"的表，键是操作数名列表（32 位 22 类、16 位 25 类）：

```racket
("bimm12" "rs1" "rs2")      -> (2 0 1)     ; (beq rs1 rs2 L)
("simm12" "rs1" "rs2")      -> (2 1 0)     ; (sw 值 基址 偏移)
("rs1_p" "rs2_p" "c_uimm8") -> (1 0 2)     ; (c.sd 值 基址 偏移)
("rd" "rs1" "rs2" "aq" "rl")-> (0 2 1 aq rl); (amoadd.d rd rs2 rs1)
```

没有登记的形状 = 还没给语法，报错而不是猜。`fence` / `fence.tso` 的字段不是普通操作数顺序，走下面的直接参数表单。

### 4.3 aq / rl 是助记符后缀

riscv-opcodes 里它们是两个 0/1 操作数；gas 里是后缀。我们只认规范写法：

```racket
(amoadd.d.aqrl rd rs2 rs1)   ; 3 个 s-exp 操作数 -> 5 个调用参数
(lr.d.aq rd rs1)
```

`.rlaq` 是拼错 → 落到"未知助记符"。非原子指令带后缀也报错。

A 扩展的全部原子指令都走这条规则：

```racket
(lr.w rd rs1)              (lr.d.aq rd rs1)
(sc.w rd rs2 rs1)          (sc.d.aqrl rd rs2 rs1)
(amoswap.w rd rs2 rs1)     (amoadd.d.rl rd rs2 rs1)
(amoand.d.aqrl rd rs2 rs1) ...
```

`lr` 是 2 个 s-exp 操作数，`sc` / `amo*` 是 3 个；`.aq` / `.rl` / `.aqrl` 不进操作数列表。

### 4.3.1 fence / fence.tso

`fence` 的 `fm` / `rs1` / `rd` 是基础 ISA 的固定/保留字段，不暴露给源码；
只暴露有语义的 `pred` / `succ`：

```racket
(fence)                ; 完整 fence = fence iorw, iorw -> 0x0ff0000f
(fence pred succ)      ; pred/succ = i,o,r,w 的规范顺序组合；0 = 空集
(fence rw rw)          ; 0x0330000f
(fence iorw iorw)      ; 0x0ff0000f
(fence r w)            ; 0x0210000f
(fence 0 0)            ; 0x0000000f
(fence.tso)            ; 0x8330000f
```

- `(fence)` 是 GAS/LLVM 的 no-operand 别名，等价于 `fence iorw, iorw`。
- 显式形式只接受 `i`, `o`, `r`, `w` 的规范顺序，每个字符最多一次：`rw` / `iorw` 合法，
  `wr` / `rwx` / 空串报错；数值只接受 `0`（空集，LLVM 也接受）。
- `fence` 接受 0 或 2 个操作数；`fence.tso` 固定 0 个，`fm/pred/succ` 由指令本身固定。
- `fence` / `fence.tso` 都不接受 `.aq` / `.rl` 后缀。

固定值已对照 `riscv-asm`、LLVM 和 GAS：

- `fence`：`imm12 = {0000,pred,succ}`，`rs1 = rd = 0`
- `fence.tso`：`imm12 = {1000,0011,0011}`，`rs1 = rd = 0`
- `pred/succ` 位：`I=8, O=4, R=2, W=1`
- 原子：`funct5[31:27]`，`aq[26]`，`rl[25]`；`lr` 是 `rd,rs1`，`sc/amo` 是 `rd,rs2,rs1`

### 4.4 字节规则

| item | 字节 |
| --- | --- |
| `label` | 无 |
| `pad n` | 由 `padding-bytes` 决定：`code` 段补合法指令，其余补 0 |
| `bytes` / `fill` | 原样 |
| `value w 值` | `w` 字节按目标端序；整数直接写，地址表达式用符号表求值（`eval-address`，与 layout 共用） |
| 真指令 | `riscv-asm` 编码（`width/8` 字节） |
| 远形式 | `riscv-help` 展开后再编码 |
| `li` / `la` | `riscv-help` 展开后再编码 |

### 4.5 填充策略（芯片相关的那一部分）

`(pad n)` 到 encode 已经是"要补 n 个字节"的事实（layout 换算好了），这里只决定**填什么**：

| 段 | 填什么 |
| --- | --- |
| `data` | `0` |
| `code` | 合法指令：4 字节优先 `nop`(`0x00000013`)，余 2 用 `c.nop`(`0x0001`) |
| `code`，余 1 / 余 3 | 报错 —— 没有任何 1 字节指令，这种对齐编不出来 |

`code` 段必须填指令：对齐补出来的字节可能真的会被执行到。
换目标（比如用 `ebreak` 填、或不允许压缩指令）只改 `target.rkt` 的这张表。

### 4.6 两条断言

1. **`(offset k item)` 是断言**：写出的字节数必须正好让它落在 `k`，
   否则说明 layout 与 encode 对尺寸的理解不一致 → 报错。
2. **layout 里还有任何 problem 就拒绝出产物**（`needs-far` / `scratch-hole` /
   `undefined-target` / `la-too-far` …）。

### 4.7 li / la

```racket
(li rd 常量)      ; 尺寸由 layout 用 li-size 精确算（4…32），这里用同一个展开器
(la rd [tmp] 链)  ; 近形式 8 字节；layout 已经保证 fits-auipc-pair?
```

`la` 的远形式（>±2GB）需要 scratch 寄存器 → 属于未实现的那一层，layout 会报 `la-too-far`。

## 5. 不归本层管

- 选指令、优化、布局、松弛：前面的层。
- 加载器格式（把 `(build …)` 写成文件）：还没做。
- 真 reloc / 外部符号：还没做。

## 6. 测试与 demo

`encode/test.rkt`（70 条）、`encode/demo.rkt`（手写 layout 产物 → `(build …)` + hexdump；
本层**不需要** layout 输入，也不需要 program / data）。

单条指令与手算编码对照（含压缩、全部原子、`fence`/`fence.tso`、别名）、`aq`/`rl` 后缀、元数、未知指令、
layout → build 字节精确、`code`/`data` 对齐补齐、`li`（4 / 8 字节）、`la`（auipc+addi 的
hi/lo 拆分）、`branch-far` 展开后的位域、拒绝出产物。

## 7. 已知缺口

- `la` 的远形式（需要 scratch）、真 reloc、外部符号。
- 没有加载器格式（`(build …)` 还只是数据结构）。
