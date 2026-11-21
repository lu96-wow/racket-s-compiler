# lower-ops 设计

`lower-ops` 把 materialize 之后的 machine IR 选成 native 形式。

它只做指令选择：

- 不新增 vreg；
- 不改 CFG；
- 不选 block 顺序；
- 不选 b/j/island；
- 不做 call / return / asm lowering。

实现：[`ir/lower.rkt`](ir/lower.rkt)。测试：[`test/lower-test.rkt`](test/lower-test.rkt)。

## 1. 输入 / 输出

输入：

```scheme
(func (main)
  (frame ...)
  (scratch ...)
  (entry b0)
  (block b0
    (const (native x12) 7)
    (load (native x5) (frame-slot 0) 0 (b64))
    ...))
```

输出仍然是 `func / block / term`，但普通 op 变成 native：

```scheme
(func (main)
  (frame ...)
  (scratch ...)
  (entry b0)
  (block b0
    (addi (native x12) (native x0) 7)
    (ld (native x5) (native x8) -24)
    ...))
```

约定：

- 操作数继续写 `(native xN)`；
- 存储指令用 native 顺序：
  - `load`：`(mnemonic rd rs1 imm)`
  - `store`：`(mnemonic imm rs1 rs2)`
- `frame-slot` 在 `load` / `store` / `addr` 里被 lower 成 `FP - offset`；
- `addr(global ...)` 和 `call` / `return` / `asm` 先原样保留。

## 2. 参数

```racket
(lower-func machine-func frame
            #:xlen 64
            #:fp '(native x8)
            #:scratch scratch-regs)
```

- `xlen`：32 / 64，决定 `ptr`、`b32` load、`b64` load/store 和 shift 立即数；
- `fp`：默认 `(native x8)`；
- `scratch`：缺省时从 func 的 `(scratch ...)` 读；可以覆盖；
- `frame`：`frame-layout` 的输出。

## 3. const / copy

| core | 条件 | native |
| --- | --- | --- |
| `(const dst imm)` | 任意整数 | `li` 展开 |
| `(copy dst src)` | `src` 是整数 | `li` 展开 |
| `(copy dst src)` | `src` 是物理寄存器 | `(addi dst src 0)` |

`li` 展开复用 `../../riscv-help/li.rkt`，然后把 `xN` 包回 `(native xN)`。

## 4. 二元算术

| core | 寄存器形式 | 立即数形式 |
| --- | --- | --- |
| `add` | `add` | `addi`，s12 |
| `sub` | `sub` | `addi dst a (-b)`，`-b` 在 s12 |
| `and` | `and` | `andi`，s12 |
| `or` | `or` | `ori`，s12 |
| `xor` | `xor` | `xori`，s12 |
| `shl` | `sll` | `slli`，0..XLEN-1 |
| `shr` | `srl` | `srli`，0..XLEN-1 |
| `sar` | `sra` | `srai`，0..XLEN-1 |
| `mul` / `div` / `divu` / `rem` / `remu` | 同名 | 无 |

规则：

- 立即数不在指令范围内时，用 scratch + `li` 装进寄存器，再走寄存器形式；
- 两个操作数都是整数时，也走 scratch + `li`；
- `add` / `and` / `or` / `xor` 允许把立即数放第二个操作数；
- `sub` 只在 `b` 是立即数且 `-b` 在 s12 时用 `addi`；
- shift 立即数范围是 `0..XLEN-1`。

## 5. load / store

### 5.1 助记符

| 类型 | load | store |
| --- | --- | --- |
| `(b8)` | `lbu` | `sb` |
| `(s8)` | `lb` | `sb` |
| `(b16)` | `lhu` | `sh` |
| `(s16)` | `lh` | `sh` |
| `(b32)` | RV64 `lwu` / RV32 `lw` | `sw` |
| `(s32)` | `lw` | `sw` |
| `(b64)` | RV64 `ld`；RV32 报错 | RV64 `sd`；RV32 报错 |
| `(ptr)` | RV64 `ld` / RV32 `lw` | RV64 `sd` / RV32 `sw` |

### 5.2 base

- `(native xN)`：base 直接使用，offset = 0；
- `(frame-slot n)`：base = FP，offset = `-(frame-slot-offset n)`；
- `global` / 整数 base：先报“需要 address lowering”。

### 5.3 offset

- `base-offset + op-offset` 在 s12：直接生成 native load/store；
- 超出 s12：
  - 用 scratch 装 offset；
  - `add scratch base scratch`；
  - load/store 的 offset 用 0。

### 5.4 顺序

```scheme
(ld  (native x11) (native x10) 0)   ; load: rd rs1 imm
(sd  0 (native x10) (native x11))   ; store: imm rs1 rs2
```

不要写成 `(sd base offset src)`。

## 6. addr

| src | 结果 |
| --- | --- |
| `(frame-slot n)` | `(addi dst fp (-offset))`，超出 s12 时 `li dst` + `add dst fp dst` |
| `(global chain)` | 先原样保留，等地址模型 / layout |
| 其它 | 报错 |

`addr` 的 dst 在 materialize 后已经是物理寄存器；如果 dst 在 slot，materialize 会用 scratch 中转。

## 7. 暂不处理

- `call`：等 call lowering / runtime contract；
- `return`：等 return lowering；
- `asm`：materialize 已显式报错；
- `addr(global ...)`：等地址模型 / layout；
- 条件分支形式：layout 负责 `eq/ne/lt/le/ltu/leu` 到 `beq/bne/blt/bge/...` 的映射；
- 远 b/j / island：layout-relax。

## 8. scratch 规则

`lower-ops` 可能使用 scratch 的场景：

- 大立即数算术；
- load/store offset 超出 s12；
- store 的 src 是整数；
- `addr` 大 offset 用 dst 自身，不需要 scratch。

一个 op 最多需要 2 个 scratch：

```text
out-of-range store + integer src
  scratch 1: address
  scratch 2: integer value
```

不足时显式报 `not enough scratch registers`。

## 9. 边界检查

- 输出没有 `($ x)`；
- `frame-slot` 在 load/store/addr 里被消除；
- 输出没有 `slot` / `vregs` / `alloc`；
- `b64` 在 RV32 上显式报错；
- 不引入 C ABI 名字；
- 不引入 b/j/island。
