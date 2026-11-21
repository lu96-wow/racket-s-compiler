# riscv-core 操作

核心操作保持**目标在前、显式 def/use**。每条普通 op 的第一个操作数是目标
（如果有），其余是源操作数。没有隐式累加器，没有隐式 `tmp`，没有物理寄存器。
`asm` 是显式例外：它的 inputs/outputs/clobber 里出现物理寄存器，边界是声明的。

## 1. 类型

类型只出现在：

- `vregs` 声明；
- `load` / `store` 的最后一个操作数；
- 以后的 frame slot。

```scheme
(b8) (b16) (b32) (b64)
(s8) (s16) (s32)
(ptr)
```

语义：

| 类型 | 含义 |
| --- | --- |
| `(bN)` | N 位存储；load 零扩展，store 截断 |
| `(sN)` | N 位存储；load 符号扩展，store 截断 |
| `(ptr)` | XLEN 指针，按 XLEN 存储 |

**算术统一按 XLEN。** 类型描述的是存储宽度和 spill slot 宽度，不是每条算术
指令的运算宽度。需要窄算术时显式写 `and` / `shl` / `shr` 等，或者以后加
明确的 `trunc` / `sext` / `zext`，不要靠类型猜。

不引入 `uint` / `int` 类型。

## 2. 值操作

```scheme
(const dst imm)
(copy dst src)

(add dst a b)
(sub dst a b)
(and dst a b)
(or  dst a b)
(xor dst a b)
(shl dst a b)
(shr dst a b)
(sar dst a b)

(mul dst a b)
(div dst a b)      ; signed
(divu dst a b)     ; unsigned
(rem dst a b)      ; signed
(remu dst a b)     ; unsigned
```

操作数：

```scheme
operand := integer | ($ name) | (global chain)
```

立即数可以直接写在源操作数位置。降低阶段负责选择 `addi` / `li` + `add`
等具体形式。

## 3. 内存

```scheme
(load  dst base offset type)
(store base offset src type)
```

- `dst` / `base` / `src` 是操作数。
- `offset` 是整数；超出立即数范围时由 lowering 展开。
- `type` 决定宽度和扩展/截断。

例子：

```scheme
(load ($ t) ($ p) 0 (b64))
(load ($ a) ($ p) 8 (b8))     ; 零扩展
(load ($ s) ($ p) 8 (s8))     ; 符号扩展
(store ($ p) 0 ($ t) (b64))
(store ($ p) 8 ($ a) (b8))    ; 截断
```

`(addr dst src)` 取地址：

```scheme
(addr ($ p) (global (d table)))   ; 全局地址
(addr ($ q) ($ x))                ; 本地地址；($ x) 必须声明 (address-taken)
```

- `src` 是 `(global chain)` 或一个 `(address-taken)` 的 vreg。
- `(address-taken)` 的 vreg 必须分配 `(slot n)`；materialize 把它变成
  frame 地址。
- `addr` 是抽象操作；materialize 后源变成 `(frame-slot n)` 或 `(global chain)`，
  仍然显式写出，例如 `(addr (native x10) (frame-slot 0))`。
- 本地 `addr(frame-slot)` 在 lower-ops 展开成 `addi` 或 `li` + `add`。
- `addr(global chain)` 在 layout-relax 保留成 `(addr-global ...)`，由
  program-layout 按目标地址解析成 `auipc` + `addi`，固定 8 字节。
- 如果 PC-relative delta 放不进 `auipc+addi`，使用绝对地址 `lui + addi`。
- 绝对地址必须能由 `lui+addi` 表示；否则显式报错。
- data 形状和布局见 [`DATA.md`](DATA.md)。

## 4. 调用

```scheme
(call dst (global chain) arg ...)
```

- `dst` 是返回值目标；没有返回值时也要写一个目标（可以是临时 vreg）。
- 参数按顺序显式写出。
- `call` 是普通 op，不是 term；返回后去哪由 block 的 `(term ...)` 明确。

```scheme
(block b0
  (call ($ r) (global (lib f)) ($ a) ($ b))
  (term (jump cont)))
```

间接调用、noreturn、异常边以后单独加，不混进当前核心。

内嵌汇编 `asm` 是特殊 op，形状不是“目标在前”：

```scheme
(asm
  (inputs ((($ a) (native x10)) ...))
  (outputs ((($ r) (native x12)) ...))
  (clobber (native x5) ...)
  (code ...))
```

它的 uses/defs/clobber 是显式的，但 `code` 由 materialize 原样发出。
详见 [`ASM.md`](ASM.md)。

## 5. 终止

终止不是 op，是 block 的最后一个 form：

```scheme
(term (jump b1))
(term (branch (eq ($ t) 0) b1 b2))
(term (return ($ t)))
(term (trap))
```

`return` 是抽象的；不写 `jalr`，不写 `ra`，不写 C ABI 返回序列。

## 6. 条件

条件只出现在 `branch` 里：

```scheme
(eq a b)
(ne a b)
(lt a b)       ; signed
(le a b)
(ltu a b)      ; unsigned
(leu a b)
```

不单独定义布尔值类型。需要布尔值时，用 `(const dst 0)` / `(const dst 1)`，
再用 `(ne dst 0)` 做条件；或者以后加显式的 setcc 操作。

## 7. lowering 的责任

核心 op 到 RISC-V 指令的选择由 lowering 负责：

| 核心 | 可能的 RISC-V |
| --- | --- |
| `const` | `li` / `lui` + `addi` |
| `copy` | `mv` / `addi`，或 coalesce 掉 |
| `add` | `add` / `addi` / `li` + `add` |
| `load (b8)` | `lbu` |
| `load (s8)` | `lb` |
| `store (b8)` | `sb` |
| `addr(global)` | `auipc` + `addi`（program-layout） |
| `call` | `jal` / `jalr`；参数/返回值由可选 ABI 层处理 |
| `return` | 返回序列（可选 ABI 层以后） |

lowering 可以在分配前或分配后发生，取决于它是否引入新的虚拟寄存器：

- 引入新 vreg 的 lowering（`const` 展开、超范围立即数）必须在分配前。
- 只改物理形式的 lowering（`load` -> `lb`）在分配后。
- 依赖地址的 lowering（`addr(global)`、远跳）在 layout 之后。

当前 `lower-ops` 已实现 `const` / `copy` / 算术 / `load` / `store` /
`addr(frame-slot)`；选择表和 native 顺序见 [`LOWER.md`](LOWER.md)。

具体规则见 [`PHASES.md`](PHASES.md)。
