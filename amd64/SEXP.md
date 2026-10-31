# amd64 s-expression 汇编形式

> 目标：形状固定、尺寸可精确计算、编码器不偷偷改 form。
> 总体计划见 [`PLAN.md`](PLAN.md)。

## 1. 通用约定

- item 是真列表：`(mnemonic operand ...)`
- 名字：symbol / string / number
- 链：非空名字列表，例如 `(main)`、`(prog1 done)`
- 地址表达式复用 `riscv/riscv-compiler/sexp.rkt` 的形状：
  ```text
  整数
  | (链)
  | (+ a b ...)
  | (- a b ...)
  ```
- 入口接受 `(quote ...)` / `(begin ...)`，出口一律 plain list
- 段、label、`value` / `bytes` / `fill` / `pad` / `align` 的语义与 RISC-V 保持一致

数据 item 继续使用：

```scheme
(label main)
(value 8 (data))
(bytes 1 2 3)
(fill 16 0)
(pad 8)
(align 16)
```

## 2. 寄存器

寄存器一律显式，不从助记符猜。

```text
64-bit: rax rcx rdx rbx rsp rbp rsi rdi r8 ... r15
32-bit: eax ecx edx ebx esp ebp esi edi r8d ... r15d
16-bit: ax cx dx bx sp bp si di r8w ... r15w
8-bit:  al cl dl bl spl bpl sil dil r8b ... r15b
        ah ch dh bh              ; 仅限不带 REX 的 8 位形式
xmm:    xmm0 ... xmm15
```

`rip` 只允许作为内存基址。

## 3. 内存操作数

内存操作数使用**命名字段**，不用位置参数和 `#f` 占位：

```scheme
(b64 (base rax) (disp 8))
(b64 (base rax) (index rcx) (scale 4) (disp 16))
(b64 (base rax) (seg fs))
```

`b8` / `b16` / `b32` / `b64` 表示内存访问宽度。暂不支持 `b128`。
字段可以按规范顺序写；解析时按字段名取值，不靠位置猜。

字段：

| 字段 | 取值 | 缺省 |
| --- | --- | --- |
| `base` | 寄存器符号或 `rip` | 无 |
| `index` | 寄存器符号 | 无 |
| `scale` | `1` / `2` / `4` / `8` | 有 index 时为 `1` |
| `disp` | 整数或地址表达式 | `0` |
| `seg` | `fs` / `gs` | 无 |

例子：

```scheme
(b64 (base rax) (disp 8))                    ; [rax+8]
(b64 (base rax))                             ; [rax]
(b64 (base rsp) (disp 16))                   ; [rsp+16]
(b64 (base rax) (index rcx) (scale 4) (disp 16))
                                               ; [rax+rcx*4+16]
(b64 (base rbp) (index rcx) (scale 8) (disp -8))
                                               ; [rbp+rcx*8-8]
(b64 (base rip) (disp (data)))               ; [rip+data]
(b64 (disp (data)))                          ; [data] 绝对 disp32
(b64 (base rax) (seg fs))                    ; fs:[rax]
(b64 (disp 16) (seg gs))                     ; gs:[16]
```

规则：

- `base` 和 `index` 必须同宽；在 64 位模式下只允许 32/64 位寄存器。
- `rsp` / `r12` 不能做 index。
- `rip` 不能和 index 同时出现。
- 没有 `index` 时 `scale` 必须省略或为 1。
- 符号位移一律按 disp32 / RIP-relative disp32 处理，不在 layout 后缩成 disp8；
  内部会用 `disp-width = 32` 固定这个选择。
- 常量位移在 normalize 阶段按值选择 `disp8` / `disp32`；一旦选定，form 不再变化。
- 任意 64 位绝对地址不直接写进内存操作数；用 `(li rd 地址)` 后通过寄存器访问。
- normalize 后的规范形式总是写出 `(disp n)`；`(base ...)` / `(index ...)` / `(seg ...)` 按需出现。

## 4. 立即数和常量

### 4.1 普通立即数

指令里的立即数可以是整数或地址表达式：

```scheme
(add rax 8)
(add rax (imm8 -1))             ; 强制 imm8 形式
(add rax (imm32 1000))          ; 强制 imm32 形式
```

为了尺寸稳定，建议：

- 编译器自己生成时优先使用 `imm8` / `imm32` 显式形式；
- 符号立即数只允许出现在明确支持重定位的形式里；
- 不要在 layout 之后才决定立即数宽度。

### 4.2 `li`

```scheme
(li rd 常量)
(li rd (链))
```

`li` 的尺寸由常量/表达式形式精确决定，类似 RISC-V 的 `li-size`：

```text
0 .. 2^32-1          -> mov r32, imm32        5 字节
-2^31 .. -1          -> mov r64, imm32        7 字节
其它 64 位值          -> movabs r64, imm64    10 字节
```

`(li rd 整数)` 展开成 `(mov rd 整数)`。
`(li rd 地址表达式)` 展开成 `(lea rd (b64 (base rip) (disp 表达式)))`。
目前只支持 RIP-relative 可达的内部标签；超出 ±2GiB 的情况还没有 far 形式/reloc。

## 5. 控制转移

### 5.1 源码形式

```scheme
(jmp (target))
(jcc cc (target))
(call (target))
```

`expand-pseudo` 会把它们规范化成明确的 size form。

### 5.2 规范化形式

```scheme
(jmp-short (target))
(jmp-near (target))
(jmp-indirect rm)

(jcc-short cc (target))
(jcc-near cc (target))

(call-near (target))
(call-indirect rm)

(ret)
```

字段：

| form | 尺寸 | 说明 |
| --- | --- | --- |
| `jmp-short` | 2 | rel8，范围 `[-128, 127]` |
| `jmp-near` | 5 | rel32，范围约 ±2GiB |
| `jcc-short` | 2 | rel8 |
| `jcc-near` | 6 | rel32 |
| `call-near` | 5 | rel32 |
| `jmp-indirect` | 2-3+ | `FF /4`，rm 是寄存器或内存 |
| `call-indirect` | 2-3+ | `FF /2` |

条件码 `cc` 只使用规范写法：

```text
o no b ae e ne be a s ns p np l ge le g
```

别名只在 `expand-pseudo` 里处理，例如：

```text
z  -> e
nz -> ne
c  -> b
nc -> ae
```

### 5.3 远形式

第一版不实现。预留：

```scheme
(jmp-far scratch (target))
(jcc-far scratch cc (target))
```

这些需要 scratch 寄存器，留给寄存器使用层。

### 5.4 `loop` / `jrcxz`

第一版不支持。它们只有 rel8，远形式需要改写序列并明确 flags 语义。

## 6. 普通指令形式

统一形式：

```scheme
(mnemonic operand ...)
```

操作数类型：

```text
register
(memXX ...)
整数 / 地址表达式
立即数形式 (imm8 n) / (imm32 n) / (imm64 n)
```

例子：

```scheme
(mov rax rbx)
(mov rax (b64 (base rbp) (disp -8)))
(mov (b64 (base rbp) (disp -8)) rax)
(movzx rax al)
(movsx rax al)
(lea rax (b64 (base rbx) (index rcx) (scale 4) (disp 8)))
(add rax 8)
(sub (b64 (base rsp)) 16)
(cmp rax 0)
(test rax rax)
(imul rax rbx)
(idiv rcx)
(cqo)
(push rax)
(pop rax)
(sete al)
(nop)
(ud2)
```

第一版指令集合：

```text
mov movzx movsx lea
add sub and or xor cmp test
inc dec neg not
shl shr sar
imul div idiv cqo cdq
push pop
setcc
nop ud2
```

`imul` 当前只支持两操作数 `(imul dst src)`。


建议后续再逐步加：

```text
adc sbb
mul div
cmovcc
bsf bsr
popcnt
SSE/AVX
```

## 7. 尺寸类别

为了让 layout 精确，规范化后的 form 必须属于有限尺寸类别：

| 类别 | 例子 | 尺寸 |
| --- | --- | --- |
| 固定 | `ret`, `nop`, `ud2`, `cqo` | 固定 |
| 寄存器/内存 | `mov rax rbx` | 固定 |
| 常量立即数 | `add rax (imm8 8)` | 固定 |
| 内存常量位移 | `(b64 (base rax) (disp 8))` | 由常量决定，normalize 后固定 |
| 符号位移 | `(b64 (base rip) (disp (data)))` | 固定 disp32/RIP |
| 短分支 | `jmp-short`, `jcc-short` | 2 |
| 近分支 | `jmp-near`, `jcc-near`, `call-near` | 固定 |

只有短分支允许在 `relax` 中升级为近分支。

## 8. normalize 规则

`expand-pseudo` 或 `normalize` 阶段负责：

1. `jmp` / `jcc` 选择 short 或 near；
2. `call` 选择 `call-near`；
3. `z` / `nz` 等条件码别名转成规范名；
4. `memXX` 的常量 displacement 选择 disp8 / disp32；
5. 常量立即数选择 imm8 / imm32 / imm64；
6. 符号 displacement 统一按 disp32/RIP；
7. 不支持的组合直接报错，不猜。

normalize 之后，`layout` 和 `encode` 不再改变 form。

## 9. 示例

### 9.1 简单代码

```scheme
((label main)
 (push rbp)
 (mov rbp rsp)
 (mov rax (b64 (base rdi)))
 (add rax 8)
 (pop rbp)
 (ret))
```

### 9.2 分支

```scheme
((label loop)
 (cmp rax 0)
 (je (done))
 (dec rax)
 (jmp (loop))
 (label done)
 (ret))
```

规范化后可能是：

```scheme
((label loop)
 (cmp rax 0)
 (jcc-short e (done))
 (dec rax)
 (jmp-short (loop))
 (label done)
 (ret))
```

`relax` 如果发现距离超出 rel8，会把对应短分支升级成 `jcc-near` / `jmp-near`。

### 9.3 内存

```scheme
(mov rax (b64 (base rdi) (index rsi) (scale 8) (disp 16)))
```

表示：

```text
mov rax, [rdi + rsi*8 + 16]
```

### 9.4 RIP-relative 数据

```scheme
(mov rax (b64 (base rip) (disp (counter))))
```

表示：

```text
mov rax, [rip + counter]
```

## 10. 与 RISC-V 形式的主要区别

| 项目 | RISC-V | amd64 |
| --- | --- | --- |
| 指令宽度 | 固定 4/2 | 1..15，必须精确 size |
| 内存操作数 | 平铺 `(lwu rd base imm)` | 命名字段 `(b64 (base ...) (index ...) (scale ...) (disp ...) (seg ...))` |
| 分支 | `bge/jal` + relax | `jmp/jcc-short/near` |
| 立即数 | `li` 精确尺寸 | `li` 精确尺寸；ALU 立即数显式 imm8/imm32 |
| 地址 | `la` / auipc+addi | RIP-relative / `li` + 寄存器 |
| 远跳 | `branch-far` / `jump-far` | 预留 `jmp-far` / `jcc-far` |
| 寄存器 | 32 个通用寄存器 | 16 个整数寄存器，需显式 REX |
