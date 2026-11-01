# amd64-asm 设计

> 本文从 x86 指令本身的编码结构倒推 `amd64-asm` 的职责边界。
> 上层流水线见 [`../ARCHITECTURE.md`](../ARCHITECTURE.md)，
> NASM 数据生成见 [`NASM.md`](NASM.md)。

## 1. x86 指令的设计逻辑

一条 x86 指令不是“助记符 + 固定字节”，而是下面这条编码流水线：

```text
legacy prefixes
  | REX
  | opcode (1..3 bytes, maybe +r / +cc)
  | ModR/M (reg field, r/m field, /digit)
  | SIB (scale, index, base)
  | displacement (0 / disp8 / disp32 / RIP-relative)
  | immediate (ib / iw / id / iq, sign or zero extension)
```

同一个 mnemonic 往往有多个 form。选择 form 的约束来自操作数，而不是来自
最终字节：

1. **mode**：当前后端只支持 64 位模式；`o16/o32/o64/o64nw/nw` 决定
   operand-size 前缀和 REX.W。
2. **operand class**：GPR8/16/32/64、XMM、内存、立即数、相对目标、隐式寄存器。
3. **width matching**：寄存器、内存宽度和立即数宽度必须来自同一个 form。
4. **memory addressing**：
   - `base` / `index` 必须是 GPR 且同宽；
   - `rsp/r12` 不能做 index；
   - `rip` 不能和 index 同时出现；
   - 常量 displacement 可选 disp8/disp32；符号 displacement 必须提前固定为 disp32；
   - 绝对 `[disp32]` 和 SIB 无 base 形式是不同编码。
5. **immediate**：
   - `ib/iw/id/iq` 有各自的宽度和符号/零扩展规则；
   - 同一 mnemonic 的 imm8 形式和 imm32 形式是不同 form；
   - 宽度选择必须在 layout 前固定，不能等最终值出来再改。
6. **prefix / REX**：
   - `66`、`F2`、`F3` 可能是 mandatory prefix，也可能是 operand-size 语义；
   - REX.W 由 form 决定；REX.R/X/B 由 reg/index/base 决定；
   - high-byte 寄存器不能和任何 REX 同时出现。
7. **control transfer**：
   - short/near 是 form，不是编码器临时选择；
   - 只有 short -> near 允许 relax；
   - far/trampoline 需要 scratch，属于更高层策略。
8. **symbolic operands**：
   - 符号 displacement / immediate 在 layout 前必须已经确定宽度；
   - 地址绑定、reloc 和最终字节是 encode 之后的事。

因此“指令生成”实际上有四个不同问题：

| 问题 | 例子 | 归属 |
| --- | --- | --- |
| form 是什么 | `adc rm64, imm8` vs `adc rax, imm32` | 指令表 + plan |
| form 是否合法 | 宽度、范围、rsp index、high8+REX | 约束检查 |
| form 多大 | prefix + opcode + RM + disp + imm | plan size |
| form 的字节是什么 | 位拼接 | encode |

把这四件事混在一个函数里，layout 就必须先编码才能知道尺寸，策略也无法独立测试。
所以 `amd64-asm` 的目标是：**指令表是数据，选择是 plan，字节生成只消费 plan。**

## 2. 目标模块结构

现有 `insn.rkt` 是历史入口；目标结构按“事实 / 表 / plan / encode”拆开：

```text
amd64-asm/
  sexp.rkt            通用 form/chain/地址表达式（尽量与 target 无关）
  facts/
    ranges.rkt        符号/无符号/disp/rel 范围事实
    registers.rkt     寄存器 class/宽度/编号/REX 属性
    target.rkt        mode / pointer width / endianness / padding
    operand.rkt       内存操作数、立即数 wrapper、分支目标形状
  table/
    nasm.rkt          生成表（或由 generated/ 提供的数据模块）
  form.rkt            表项模型：mnemonic + operand pattern + encoding tokens
  plan.rkt            约束检查 + form 选择 + instruction-plan + plan-size
  encode.rkt          instruction-plan -> bytes
  special/
    mov.rkt           mov 的立即数策略
    control.rkt       jmp/jcc/call 的显式 form
    prefix.rkt        lock/rep 包装
    string.rkt        movs/stos/ins/outs
    system.rkt        cr/dr、descriptor table 等特殊寄存器
  insn.rkt            对外 facade：plan / size / encode / known? / arity
  binary-build/       NASM -> table 的生成流水线
```

### 2.1 事实层

只放不会因布局改变的事实：

- 寄存器名字、class、宽度、编码编号、REX 属性；
- target mode、指针宽度、端序、填充；
- 内存操作数的字段和宽度；
- 立即数 wrapper 的形状；
- 地址表达式形状和求值接口。

不放：form 选择、段、label、寄存器分配、ABI。

### 2.2 表 / form 层

每个 form 只描述“这个编码形状是什么”：

```text
mnemonic
operand patterns (gpr/rm/mem/xmm/imm/rel)
prefix bytes / opcode bytes / +r
ModR/M roles / SIB 需求
size mode (o8/o16/o32/o64/nw/osz)
immediate kind + range
source provenance / flags
```

表的来源可以不同：

- NASM 生成表：通用 legacy/SSE form；
- 手写 special form：公共拼写和 NASM 不是一一对应的 form；
- 未来的其他来源（比如显式 pseudo form）也只能生成同一套 form 模型。

表本身不决定“用哪个 form”；它只提供候选。

### 2.3 plan 层

`plan` 是约束检查和 form 选择的唯一场所：

```text
operands
  -> normalize
  -> match candidate forms (arity / kinds / widths / ranges)
  -> check addressing and prefix/REX legality
  -> choose one form (shortest / explicit policy)
  -> instruction-plan
       fixed form
       fixed prefix/REX
       fixed ModR/M + SIB + displacement plan
       fixed immediate width/value
       plan-size
```

关键不变量：

- `plan-size` 和 `encode-plan` 使用同一份 plan 字段；
- layout 只调用 plan/size，不要求字节；
- 选择策略变化只改 plan，不改 encode；
- encode 不再重新匹配操作数，也不选择 immediate/displacement 宽度。

### 2.4 encode 层

`encode-plan` 只做：

```text
wait prefix + segment prefix + mandatory prefixes + REX
+ opcode + ModR/M + SIB + displacement + immediate
```

它是纯函数，输入是已经确定的 plan。它不做：

- 不选 form；
- 不查寄存器表以外的策略；
- 不解析 label；
- 不改变plan 的宽度；
- 不把 short 改成 near。

### 2.5 facade

`insn.rkt` 只保留稳定的公共入口：

```racket
(instruction-plan target name operands) ; -> plan
(plan-size plan)
(encode-plan plan)
(encode-instruction target name operands) ; plan + encode 便利入口
(instruction-size target name operands)  ; plan-size 便利入口
(known-instruction? name)
(instruction-arity name)
```

上层 layout 应该逐步从 `instruction-size` 迁移到 `instruction-plan` +
`plan-size`，这样布局阶段拿到的不只是数字，还能看到 form/prefix/REX 决策。

## 3. 约束归属

| 约束 | 唯一归属 | 说明 |
| --- | --- | --- |
| integer/immediate range | `facts/ranges.rkt` | plan、special、help 共用 |
| register name/class/width/index | `facts/registers.rkt` | 不重新维护 |
| target mode/pointer width | `facts/target.rkt` | mode 必须进 target |
| memory field legality | `facts/operand.rkt` | base/index/scale/disp/seg |
| form syntax | `form.rkt` / 生成表 | 只描述形状 |
| operand width/kind | `plan.rkt` | 匹配 form |
| immediate range | `plan.rkt` | 使用共享 ranges 语义 |
| ModR/M/SIB legality | `plan.rkt` + `facts/operand.rkt` | 产生 `rm-encoding` plan |
| high8 + REX | `plan.rkt` | 在 plan 阶段报错 |
| operand-size/REX.W | `plan.rkt` | 由 form 的 size mode 决定 |
| branch short/near | `special/control.rkt` / `amd64-help` | form 不是 encoder 临时选 |
| symbolic width | `amd64-help` / plan | layout 前固定 |
| 最终字节 | `encode.rkt` | 纯拼接 |
| layout/relax/binding | `compiler` | amd64-asm 不知道 |

## 4. 现有代码的迁移映射

| 现状 | 目标 |
| --- | --- |
| `insn.rkt` 里 1000+ 行特殊 encoder | `special/*.rkt`，统一产出 plan |
| `insn-generic.rkt` 内 `try-plan-entry`/`encode-plan` | 拆到 `plan.rkt` / `encode.rkt` |
| `insn-core.rkt` | 保留为底层字节/ModR/M/REX helpers，或并入 `facts/operand` + `encode` |
| `sexp.rkt` 的 amd64 内存形状 | 移到 `facts/operand.rkt`，`sexp.rkt` 只留通用形状 |
| `target.rkt` 没有 mode | 加 `mode`，当前只接受 64 |
| `insn.rkt` 的 `mov` 策略 | `special/mov.rkt`，输出固定 imm 宽度的 form |
| `insn.rkt` 的 `prefix`/string/system | 各自 special 模块 |
| 生成表数据 | `table/nasm.rkt`，不再和特殊 encoder 混在一起 |

迁移期间允许 facade 同时调用 special 和生成表，但两者都要返回同一种 plan 形状；
最终 `instruction-size` 不再以 `encode-instruction` 为唯一实现。

## 4.1 当前迁移状态

已经落地：

- `insn.rkt` 只保留 facade；
- `operand.rkt` 收纳操作数解析和 symbolic immediate 策略；
- `special.rkt` 收纳原手写特殊 encoder/表；
- `plan.rkt` 提供统一 `resolved-plan`，generated 和 special 都走
  `instruction-plan -> plan-size/encode-plan`；
- `instruction-size` 对两类指令都走 plan，不再以 `encode-instruction`
  作为唯一尺寸来源；
- `generated` 表继续由 `binary-build/` 生成。

仍待完成：

- `special.rkt` 仍以“直接产出 bytes”的旧 encoder 为主体；下一步把
  `mov/control/prefix/string/system` 各自改成返回 plan 片段；
- `sexp.rkt` 的 amd64 内存形状还未迁到 `facts/operand.rkt`；
- `target.rkt` 还没显式包含 mode。

## 5. 不变量

1. 一个 form 只对应一种编码类别。
2. 表只产生候选，不直接决定策略。
3. 约束检查先于字节生成。
4. layout 前固定 immediate/displacement 宽度。
5. `plan-size` 与 `encode-plan` 共用 plan 字段。
6. encode 不改 plan。
7. 不合法组合必须在 plan 阶段大声失败，不能静默生成错误字节。
8. `amd64-asm` 不 require `compiler`、`amd64-help` 或 `loko-compatibility`。

## 6. 边界

`amd64-asm` 不负责：

- 段/放置/标签；
- branch relaxation；
- 地址绑定；
- 寄存器分配/scratch；
- ABI/调用约定；
- ELF/loader/reloc；
- Loko 旧写法。

这些属于 `amd64-help`、`compiler` 或可选前端/镜像层。
