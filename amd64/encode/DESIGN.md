# amd64 encode 层（第一版）

> 当前只做“单条已规范化 amd64 指令 -> 字节”。标签解析、布局、relax 还没接进来。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| 物理寄存器查找 | 寄存器分配 |
| `b8/b16/b32/b64` 内存操作数解析 | 符号位移求值 |
| ModR/M、SIB、disp、REX、前缀编码 | 分支松弛 |
| 小范围整数指令 | AVX / 完整 x86 |
| 分支相对偏移编码 | 标签绑定 |

## 2. 输入

```racket
(encode-instruction name operands)   ; -> bytes?
```

- `name` 是规范化后的 form，例如 `mov`、`add`、`jmp-short`、`jcc-near`。
- `operands` 里的寄存器是物理寄存器名。
- 内存操作数是 `amd64/sexp.rkt` 的 `mem`：
  ```scheme
  (b64 (base rax) (index rcx) (scale 4) (disp 16))
  ```
- 分支/跳转的操作数是**已经算好的相对偏移**（整数），不是 label。
- 内存 displacement 目前要求是已解析的整数。

## 3. 当前支持的 form

```text
mov movzx movsx lea
add sub and or xor cmp test
inc dec neg not
shl shr sar
imul div idiv cqo cdq
push pop
jmp-short jmp-near
jcc-short jcc-near
call-near
call-indirect jmp-indirect
setcc
ret nop ud2
```

## 4. 编码结构

```text
legacy prefixes
  segment override (fs/gs)
  operand-size (0x66)
REX
opcode
ModR/M
SIB
displacement
immediate
```

- `make-rex` 负责 W/R/X/B 和 high-byte 寄存器冲突检查。
- `encode-rm` 负责寄存器与内存的 ModR/M；`encode-mem-rm` 负责 SIB 和 disp8/disp32。
- `emit-rm` 把前缀、opcode、ModR/M、SIB、disp、immediate 串起来。
- 指令表 `instruction-table` 只存 arity 和编码过程；目前是“小表 + 专用函数”，后续再抽成更完整的编码表。
- `instruction-size` 和 `encode-instruction` 走同一套编码逻辑，避免尺寸/字节不一致。

## 5. 已知缺口

- 单独的 `encode-instruction` 仍要求 displacement 是整数；
  `encode-layout` 会先把符号 displacement 解析成整数。
- `imm8/imm16/imm32/imm64` 包装目前只取数值，不强制宽度。
- `imul` 目前只支持两操作数形式；三操作数和单操作数形式还没实现。
- 还不会生成 `b128` / SSE / AVX。
- 分支 far form 和 scratch 寄存器没有实现。

## 6. 测试

```sh
racket amd64/encode/test.rkt
```

当前覆盖：

- 寄存器/寄存器 `mov`
- 寄存器/内存 `mov`
- RIP-relative、绝对 `[disp32]`、SIB
- `lea`
- `add/sub/cmp` 寄存器与立即数
- `mov` 立即数（32/64 位、movabs）
- 8 位 high-byte / REX 字节
- `push/pop`
- `jmp/jcc/call` 的 short/near 编码
