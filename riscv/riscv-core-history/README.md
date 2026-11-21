# riscv-core

`riscv-core` 是一套重新设计的 RISC-V 核心 IR。它和 `../riscv-compiler` 并列：
`riscv-compiler` 继续作为现有后端；这里从 s-exp 形状和阶段边界重新开始，一步一步验证。

当前状态：**前端 module 解析、virtual IR 验证、CFG、liveness、分配生成（干涉图着色 + spill）、allocation 表验证、frame-layout、materialize、lower-ops、call/return lowering、machine IR 验证、layout plan / layout-relax / program-layout、内部 call-target 近/远解析、data 段布局、data label、`addr(global)`、data 地址初值、全局地址远形式 fallback、raw 纯汇编单元、inline asm materialize / layout / encode、函数内 islands、统一 driver + scratch budget 反馈、source -> bytes 端到端、encode（单函数 + 程序级，固定 32-bit native）已实现并有测试；interface source / extern 表、relocation、address data、最小 link 已实现；object/ELF、linker relaxation、任意 64-bit 全局地址、island 共享 / 链、混合 island/inline policy、RVC 还没有实现。**

## 目标

1. 所有结构都是 proper list，**不使用 dotted pair**，不依赖字符串前缀解析。
2. 变量先是**虚拟寄存器**，物化寄存器是独立层；两者在代码里不能混
   （`asm` 的 inputs/outputs/clobber 是显式边界）。
3. 控制流是**显式的 block + term + 边**，不把 `j` / `b` / `label` 写进核心 IR
   （`asm.code` / `raw` 的 machine 层除外）。
4. 核心 IR 不含 C ABI：不出现 `a0` / `ra` / `sp`，不出现 prologue/epilogue。
5. 分配前只改 vreg / CFG / def-use；分配后才做位置相关改写、布局和编码。
6. 每一步都能用纯 list 操作验证：`match`、`assoc`、`equal?`。
7. `module` 只在前端解析；后端输入里没有 `module` / `provide` / `require`。

## 文件夹

| 文件 | 内容 |
| --- | --- |
| [`SYNTAX.md`](SYNTAX.md) | 核心 s-exp 形状：顶层、func、block、term、vreg、allocation |
| [`OPS.md`](OPS.md) | 核心操作：算术、内存、`addr`、`call`、类型 |
| [`DATA.md`](DATA.md) | 全局 data 形状、item、尺寸、对齐、`addr(global)`、布局边界 |
| [`CONTROL.md`](CONTROL.md) | 控制流：block、term、边、布局如何物化 `j` / `b` |
| [`PHASES.md`](PHASES.md) | 虚拟 IR / allocation / machine IR 的边界与 pass 顺序 |
| [`MEMORY.md`](MEMORY.md) | 内存 / 栈模型、frame layout、runtime contract、GC roots |
| [`LOWER.md`](LOWER.md) | lower-ops 选择表、native 顺序、scratch 规则 |
| [`CALL.md`](CALL.md) | call / return lowering、runtime contract、outgoing args、stack map 方向 |
| [`MODULES.md`](MODULES.md) | module / provide / require、多文件、全局名与函数局部名 |
| [`ASM.md`](ASM.md) | 纯汇编 `raw` 与内嵌 `asm` |
| [`RAW.md`](RAW.md) | `raw` 的 machine item、label、控制转移、布局和编码边界 |
| [`STATUS.md`](STATUS.md) | 全局设计、当前完成度、P0/P1/P2 缺口、建议顺序 |
| [`REVIEW.md`](REVIEW.md) | 全局边界、已修冲突、未定点、决策顺序 |
| [`PLAN.md`](PLAN.md) | 一步一步的验证计划与验收标准 |
| [`core/sexp.rkt`](core/sexp.rkt) | 跨层共享的 form / name / chain / tagged operand 形状 |
| [`frontend/README.md`](frontend/README.md) | 前端 module 解析实现：collect / link / rewrite |
| [`ir/README.md`](ir/README.md) | virtual IR 实现：shape / verify / cfg / analysis / liveness / allocation / allocate / frame / materialize / lower / call / verify-machine |
| [`ir/scratch.rkt`](ir/scratch.rkt) | scratch 形状、去重、func 顶层读取、pool |
| [`data/data.rkt`](data/data.rkt) | data 形状、item 校验、尺寸、字节生成 |
| [`raw/raw.rkt`](raw/raw.rkt) | raw 形状、label、控制转移、固定 4 字节规范化 |
| [`asm/code.rkt`](asm/code.rkt) | inline asm code 块：局部 label、控制转移、固定 4 字节规范化 |
| [`driver/compile.rkt`](driver/compile.rkt) | 统一 driver：source / resolved -> bytes，scratch budget 反馈 |
| [`link/README.md`](link/README.md) | interface source / extern / relocation / address data / 最小 link |
| [`link/external.rkt`](link/external.rkt) | extern 和 address data 形状 |
| [`link/reloc.rkt`](link/reloc.rkt) | relocation 记录 |
| [`link/link.rkt`](link/link.rkt) | 最小 link：address data 回填 relocation |
| [`layout/README.md`](layout/README.md) | 布局策略、layout-plan、layout-relax、program-layout、island / scratch 方向 |
| [`encode/README.md`](encode/README.md) | layout-result / program-layout -> bytes、label offset、section 拼接 |
| [`test/`](test/) | `frontend-test.rkt`、`verify-test.rkt`、`cfg-test.rkt`、`liveness-test.rkt`、`allocation-test.rkt`、`allocate-test.rkt`、`frame-test.rkt`、`materialize-test.rkt`、`lower-test.rkt`、`call-plan-test.rkt`、`call-lower-test.rkt`、`verify-machine-test.rkt`、`layout-plan-test.rkt`、`layout-relax-test.rkt`、`layout-program-test.rkt`、`encode-test.rkt`、`stack-call-test.rkt`、`data-test.rkt`、`data-layout-test.rkt`、`raw-test.rkt`、`asm-code-test.rkt`、`layout-islands-test.rkt`、`driver-test.rkt`、`external-test.rkt` |
| [`examples/`](examples/) | 纯数据示例，后续测试可以直接 `require` |

## 最小例子

虚拟 IR：

```scheme
(func (main)
  (vregs
    (($ a) (b8))
    (($ b) (b8))
    (($ t) (b64)))
  (entry b0)
  (block b0
    (add ($ t) ($ a) ($ b))
    (term (return ($ t)))))
```

分配结果：

```scheme
(allocation
  (($ a) (native x10))
  (($ b) (native x11))
  (($ t) (native x12)))
```

物化后的 machine IR：

```scheme
(func (main)
  (entry b0)
  (block b0
    (add (native x12) (native x10) (native x11))
    (term (return (native x12)))))
```

## 和现有目录的关系

| 目录 | 用途 |
| --- | --- |
| `../riscv-asm` | 指令表、编码、寄存器编号；`riscv-core` 的最终编码仍然用它 |
| `../riscv-help` | `li` / `la` / 远形式展开；以后由 lowering/layout 调用 |
| `../riscv-compiler` | 现有扁平 item 后端；本目录不复用它的 IR，只通过它的 `api.rkt` 用指令编码与 target 事实 |
| `../riscv-compiler-test` | 现有测试；`riscv-core` 的测试独立放在本目录 |

## 非目标

- 不做 C ABI。
- 不做完整语言前端；只定义模块/名字解析这一层，以及核心 IR 收到的形状。
- 不引入 `unit` 包装；顶层直接是 `func` / `data` / `raw` 的序列，或用 `module` 分组。
- 不引入 `uint` 类型；宽度 + 操作有无符号已经足够。
- 不在核心 IR 里做寄存器分配、spill、布局、编码。
