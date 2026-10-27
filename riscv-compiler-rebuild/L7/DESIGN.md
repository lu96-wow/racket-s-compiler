# L7 编码（`L7/target.rkt` `L7/insn.rkt` `L7/encode.rkt`）

> 最后一步：`layout -> (build …)`，每个段一坨字节。
> **端序只出现在这里**；指令编码和位域检查都在 `riscv-asm`。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| 逐 item 出字节（数据 + 代码） | 选指令 / 优化 |
| 端序、对齐补齐 | 布局（属于 L5） |
| `value` / `label+` 求值 | 松弛（属于 L6） |
| `li` / `la` / 远形式展开 | 填 scratch 空槽（未实现的那一层） |
| 断言"写出的字节数 = L5 的偏移" | 加载器格式 / ELF / 分区镜像 |
| 有 problem 就拒绝出产物 | — |

## 2. 输入 / 输出

```
layout : L6 产物（segments + symbols + problems）
  ↓
(build (segment (name s) (start #x1000) (size 12) (bytes #vu8…)) ...)
```

## 3. API

| 文件 | API |
| --- | --- |
| `target.rkt` | `target-word-size` `target-endianness` `target-extensions` `integer->bytes` `code-padding-bytes` |
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

所以 L7 **不写**任何合法性检查。

### 4.2 操作数顺序（本层唯一的公开接口约定）

riscv-opcodes 的声明顺序（= rebuilt 函数参数顺序）不是汇编写法：
分支/存储/原子把合并后的立即数放在第一位。

```racket
(beq bimm12 rs1 rs2)      ; 函数
(beq rs1 rs2 L)           ; 我们写
```

`L7/insn.rkt` 有一张"调用位置 ← s-exp 位置"的表，键是操作数名列表（32 位 22 类、16 位 25 类）：

```racket
("bimm12" "rs1" "rs2")      -> (2 0 1)     ; (beq rs1 rs2 L)
("simm12" "rs1" "rs2")      -> (2 1 0)     ; (sw 值 基址 偏移)
("rs1_p" "rs2_p" "c_uimm8") -> (1 0 2)     ; (c.sd 值 基址 偏移)
("rd" "rs1" "rs2" "aq" "rl")-> (0 2 1 aq rl); (amoadd.d rd rs2 rs1)
```

没有登记的形状 = 还没给语法（目前是 `fence` / `fence.tso`），报错而不是猜。

### 4.3 aq / rl 是助记符后缀

riscv-opcodes 里它们是两个 0/1 操作数；gas 里是后缀。我们只认规范写法：

```racket
(amoadd.d.aqrl rd rs2 rs1)   ; 3 个 s-exp 操作数 -> 5 个调用参数
(lr.d.aq rd rs1)
```

`.rlaq` 是拼错 → 落到"未知助记符"。非原子指令带后缀也报错。

### 4.4 字节规则

| item | 字节 |
| --- | --- |
| `label` | 无 |
| `align n` | 补到**绝对地址**对齐；`code` 段补 `nop`（会顺着执行），其余补 0 |
| `bytes` / `fill` | 原样 |
| `value w 值` | `w` 字节按目标端序；整数直接写，`(label+ 链 加数)` 用符号表求值 |
| 真指令 | `riscv-asm` 编码（`width/8` 字节） |
| 远形式 | `riscv-help` 展开后再编码 |
| `li` / `la` | `riscv-help` 展开后再编码 |

`code` 段的 padding 用 `nop`（`0x00000013`）：对齐补出来的字节可能真的会被执行到。

### 4.5 两条断言

1. **`(offset k item)` 是断言**：写出的字节数必须正好让它落在 `k`，
   否则说明 L5 与 L7 对尺寸的理解不一致 → 报错。
2. **layout 里还有任何 problem 就拒绝出产物**（`needs-far` / `scratch-hole` /
   `undefined-target` / `la-too-far` …）。

### 4.6 li / la

```racket
(li rd 常量)      ; 尺寸由 L5 用 li-size 精确算（4…32），这里用同一个展开器
(la rd [tmp] 链)  ; 近形式 8 字节；L5 已经保证 fits-auipc-pair?
```

`la` 的远形式（>±2GB）需要 scratch 寄存器 → 属于未实现的那一层，L5 会报 `la-too-far`。

## 5. 不归本层管

- 选指令、优化、布局、松弛：前面的层。
- 加载器格式（把 `(build …)` 写成文件）：还没做。
- 真 reloc / 外部符号：还没做。

## 6. 测试（`L7/test.rkt`，57 条）

单条指令与手算编码对照（含压缩、原子、别名）、`aq`/`rl` 后缀、元数、未知指令、
layout → build 字节精确、`code`/`data` 对齐补齐、`li`（4 / 8 字节）、`la`（auipc+addi 的
hi/lo 拆分）、`branch-far` 展开后的位域、拒绝出产物。

## 7. 已知缺口

- `la` 的远形式（需要 scratch）、真 reloc、外部符号。
- 没有加载器格式（`(build …)` 还只是数据结构）。
- `fence` / `fence.tso` 的操作数语法没定义。
