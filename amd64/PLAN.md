# amd64 后端计划

> 与 `riscv/riscv-compiler` 分离实现。
> 当前架构见 [`ARCHITECTURE.md`](ARCHITECTURE.md)，s-exp 形状见 [`SEXP.md`](SEXP.md)，
> 总索引见 [`README.md`](README.md)。

## 1. 目标

先做一个**可测试、可逐步扩展**的 amd64 后端：

1. 明确的 amd64 s-expression 汇编形式。
2. 表驱动的指令编码器，尺寸和编码共用同一张表。
3. 精确的 item 尺寸，`layout` 不再把代码当固定 4 字节。
4. 分支只做 `short -> near` 的只增松弛；不收缩。
5. 不追求第一版覆盖全部 x86，只覆盖编译器实际会生成的整数/控制流/基本内存指令。

暂不处理：

- AVX / VEX
- 完整 x86 指令集
- 外部符号、ELF、加载器
- 寄存器分配和 scratch 填充
- `loop` / `jrcxz` 远形式

## 当前进度

- [x] `amd64/SEXP.md`：形式定稿（内存宽度 `b8/b16/b32/b64`，命名字段）
- [x] `amd64/sexp.rkt`：通用形状 + 内存操作数解析
- [x] `amd64/expand-data`：rich 数据 -> 核心数据 item（复用 RISC-V 的 target-neutral 实现）
- [x] `amd64/flatten`：module/provide/require 名字解析（复用 RISC-V 的 target-neutral 实现）
- [x] `amd64/registers.rkt`：寄存器表（共享事实）
- [x] `amd64/insn.rkt`：第一版整数/控制流编码 + `instruction-size`（layout/encode 共享）
- [x] `amd64/expand-pseudo/rewrite.rkt`：`jmp/jcc/call/li` 与条件码别名规范化
- [x] 编码测试、expand-pseudo 测试、expand-data 测试、flatten 测试
- [x] `layout` 精确尺寸与段布局（第一版扁平 item + program blocks 桥接）
- [x] `bind-labels`
- [x] `encode-layout` 端到端字节输出
- [x] `analyze` / `dce`（amd64 控制流分类）
- [x] `flow`（默认流含 relax）
- [x] `relax`（short -> near 只增）
- [x] 符号 memory displacement（归一化为固定 disp32，encode 时解析）
- [x] 基本整数指令扩展（test/inc/dec/neg/not/shift/imul/div/idiv/movzx/movsx/setcc/cqo/cdq）
- [x] 结构清理：`item.rkt` / `insn.rkt` 共享事实；layout 不再依赖 encode；target 显式传参；flow 检查伪指令残留
- [x] `li` 整数 -> mov，地址表达式 -> RIP-relative lea
- [x] `loko-compat`：Loko 旧汇编写法 -> 核心 item 的纯变换
- [x] `comment` 零尺寸 item、`cmovcc`、`b128` 内存宽度事实
- [x] 整数扩展：`imul` 1/2/3、shift by `cl`、`push/pop` 内存/立即数、`xchg/bswap/bsf/bsr/popcnt/shrd`
- [x] 系统/原子/端口/屏障指令：`cdqe cpuid rdtsc rdtscp syscall in out cmpxchg xadd rdrand rdseed clflush fences`
- [x] 前缀与字符串指令：`(prefix lock/rep …)`、`movs/stos/ins/outs`
- [ ] SSE/xmm、`adc/sbb`
- [ ] PC 控制面：control/debug registers、`lgdt/lidt/lldt/ltr`、`wrmsr/rdmsr`、`swapgs/sysretq/iretq/jmpf`、16/32 模式
- [ ] image 层：`%section` / `%comm` / `%origin` / `%mode` / `%call`
- [ ] `place` region / 通配、外部 reloc

## 2. 总体流水线

第一版建议保持与 RISC-V 相同的层形状：

```text
rich data
  -> expand-data
  -> flatten
  -> expand-pseudo
  -> analyze
  -> dce
  -> layout          ; amd64 精确尺寸
  -> relax           ; jmp/jcc short -> near
  -> bind-labels
  -> encode
```

关键区别：

- `layout` 的代码尺寸必须来自 amd64 的编码表，而不是固定 4 字节。
- `relax` 只升级控制转移 form，其他尺寸在 layout 前固定。
- `encode` 与 `layout` 共用同一张 `insn-size` / `insn-encode` 表，避免尺寸和字节不一致。

## 3. 尺寸策略

### 3.1 第一版：固定 long form

为了先得到正确闭环，第一版可以让 `expand-pseudo` 统一生成：

```text
jmp-near   5
jcc-near   6
call-near  5
```

这样：

- 不需要 relax；
- 不需要 NOP 补缩；
- `layout` 直接按固定尺寸；
- 先验证编码器、标签、相对位移、对齐和段布局。

### 3.2 第二版：short 起步，只增不减

确认 long form 闭环后，再让 `expand-pseudo` 生成：

```text
jmp-short  2
jcc-short  2
```

`relax` 只做：

```text
jmp-short -> jmp-near
jcc-short -> jcc-near
```

规则：

- 只升级，不降级；
- 不生成新 label；
- 不拆块；
- 对齐 padding 可以变小，但不要求 padding 单调；
- 其他尺寸（imm8/imm32、disp8/disp32、REX）在 layout 前固定。

### 3.3 远形式

只有在代码段超过 ±2GiB 或 JIT/外部地址不可控时才考虑：

```text
jmp-far
jcc-far
call-indirect
```

这些需要 scratch 寄存器，留给之后的寄存器使用层。

## 4. 尺寸固定的规则

`layout` 要精确，所以所有非控制流尺寸在进入 layout 前必须确定：

| 项目 | 规则 |
| --- | --- |
| 寄存器宽度 | 由寄存器名决定 |
| REX | 由寄存器和操作数宽度决定 |
| ModR/M / SIB | 由寻址形式决定 |
| `disp8` / `disp32` | 常量位移在 layout 前选；符号位移一律 disp32 |
| `imm8` / `imm32` / `imm64` | 常量在 layout 前选；符号立即数只允许出现在 `li` 等明确形式 |
| `li` | 由常量精确决定尺寸 |
| 分支 | `jmp/jcc` 的 short/near 是 form，不是 encoder 临时决定 |
| `align` | 由 layout 根据绝对/相对地址计算 |

编码器不允许在 layout 之后偷偷把 `disp32` 改成 `disp8`，也不允许把 `near` 改成 `short`。

## 5. 文件计划

```text
amd64/
  PLAN.md
  SEXP.md
  target.rkt
  sexp.rkt
  expand-data/
  flatten/
  expand-pseudo/
  analyze/
  dce/
  layout/
  relax/
  bind-labels/
  encode/
  flow/
```

### 各层职责

| 层 | 内容 |
| --- | --- |
| `target.rkt` | `target-amd64`、指针宽度、代码段 NOP padding、端序 |
| `sexp.rkt` | item / chain / 地址表达式；amd64 内存操作数判定 |
| `loko-compat` | Loko 旧汇编写法（memN+、%label、%uN 等）-> 核心 item |
| `expand-data` | 先复用 RISC-V 的数据展开规则 |
| `flatten` | 名字解析，可复用 RISC-V 实现 |
| `expand-pseudo` | `jmp/jcc/call`、`ret`、`nop`、`li`、常见 mov/算术别名 |
| `analyze` | amd64 的分支/跳转/终止指令分类、CFG |
| `dce` | 与 RISC-V 同构 |
| `layout` | 精确 item 尺寸、对齐、anchor、范围请求 |
| `relax` | `short -> near` 单调升级 |
| `bind-labels` | anchor -> symbol / 绝对地址 |
| `encode` | 表驱动编码，输出每段字节 |
| `flow` | stage 表和选择器 |

## 6. 编码器设计

建议每种 form 对应一条表项：

```racket
(struct encoding (size encode))   ; 伪代码
```

`layout` 只调用 `size`；`encode` 只调用 `encode`。两者必须由同一张表生成。

表项至少包含：

```text
mnemonic / form
操作数形状
固定字节数或 size 函数
编码函数
```

第一版指令集：

```text
mov, movzx, movsx, lea
add, sub, and, or, xor, cmp, test
inc, dec, neg, not
shl, shr, sar
imul, idiv, cqo/cdq
push, pop
call, jmp, jcc, ret
setcc
nop, ud2
```

先不覆盖 SSE/AVX。

## 7. 实施阶段

### Phase 0：文档和形状

- 定稿 `SEXP.md`
- 定稿 `target-amd64`
- 写 `sexp.rkt` 的 amd64 形状判定
- 写最小 encoding 表骨架

### Phase 1：单条指令编码

- `mov` 寄存器/内存/立即数
- `add/sub/cmp` 等基本 ALU
- `jmp/jcc/call/ret`
- 单条指令尺寸测试
- 手算字节 golden test

### Phase 2：标签和段

- `layout` 精确尺寸
- `bind-labels`
- `encode` 相对位移
- `align` / `pad`
- 小段字节 golden test

### Phase 3：控制流和数据

- `expand-data` / `flatten`
- `analyze` / `dce`
- 最小完整程序
- `relax` 先 no-op，保持 long form

### Phase 4：short branch

- `jmp-short` / `jcc-short`
- `relax` 只增
- 边界测试 `-128/127`
- 对齐和级联升级测试

### Phase 5：后端接入

- `flow` 选择器
- demo/test
- 后续再讨论寄存器分配和 far form

## 8. 测试计划

每层一个 `test.rkt`，至少覆盖：

- 寄存器宽度、REX、ModR/M、SIB
- `[base]`、`[base+disp8]`、`[base+disp32]`
- `[base+index*scale+disp]`
- RIP-relative
- 绝对 `[disp32]`
- 立即数边界：`-128/127`、`-2^31/2^31-1`、`2^32-1`、64 位
- `jmp/jcc/call` 相对位移
- short/near 边界 `-128/127`
- `align` 填充
- `layout` 的 `(offset k item)` 断言
- 未知 label / 未定义目标
- `relax` 单调收敛
- 代码段 NOP padding 任意长度

## 9. 待确认

1. 第一版是否直接 short 起步，还是先 near-only？
2. `call` 在 `analyze` 中按普通指令还是块终止处理？
3. `li` 是否允许所有 64 位常量，还是只允许编译器实际用到的范围？
4. 是否现在就把 `amd64` 的公共层与 RISC-V 抽到 `common/`，还是先复制保持独立？

已定：

- 内存形式采用命名字段形式：`(b64 (base ...) (index ...) (scale ...) (disp ...) (seg ...))`，不用位置参数和 `#f` 占位。
