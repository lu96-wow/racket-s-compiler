# 全局设计 / 当前状态

本文只做全局整理，不展开实现细节。细节见各层 README 和设计文档。

## 1. 定位

`riscv-core` 是一个从 s-exp 形状重新设计的 RISC-V 编译后端：

```text
module / resolved IR
  -> virtual IR
  -> allocation
  -> machine IR
  -> layout
  -> encode
```

它当前不是完整语言编译器，也不是完整链接器。  
它已经能覆盖“一个内部程序从 IR 到机器字节”的主干，但还缺驱动、外部链接、运行时和若干边界能力。

## 2. 全局目标（不变）

1. 所有结构是 proper list；不用 dotted pair；不靠字符串前缀解析。
2. 变量先是虚拟寄存器；物理寄存器物化是独立层；两者不能混。
3. 控制流是 block + term + 边；`j` / `b` / `label` 只属于 layout 之后。
4. 核心 IR 不含 C ABI：没有 `a0` / `ra` / `sp`，没有 prologue/epilogue。
5. 分配前只改 vreg / CFG / def-use；分配后只做位置相关改写。
6. module 只在 frontend；backend 不看到 `module` / `provide` / `require`。
7. 每层只处理自己关心的事；跨层借用必须显式。

## 3. 当前主流水线

```text
source forms
  -> frontend collect / link / rewrite
  -> resolved func / data / raw
  -> virtual IR verify
  -> CFG
  -> liveness
  -> allocate + scratch
  -> allocation verify
  -> materialize
  -> machine IR verify
  -> call-plan
  -> frame-layout
  -> lower-ops
  -> call-lower
  -> layout-plan / layout-relax（函数内，含 inline / islands）
  -> program-layout（func / raw / data，call-target，addr）
  -> encode-program
  -> bytes + section labels
```

## 4. 已实现的能力

| 层 | 已完成 |
| --- | --- |
| frontend | 顶层 module、隐式根、provide/require、prefix-in、rename-in/out、re-export、循环 require、raw label、data label、data body 全局名解析 |
| core shape | form / name / chain / `($ x)` / `(native xN)` / `(global chain)` |
| virtual IR | shape、verify、CFG、前驱后继、可达性、def-use、liveness、live-in/out |
| allocate | 干涉图着色、pin、reserve、clobber、address-taken、spill 到 slot、scratch budget、asm clobber 并集 |
| allocation verify | 缺项、重复、pin/reserve、address-taken、scratch 去重 |
| frame | slot size/align、FP 相对偏移、header/outgoing、frame 对齐 |
| materialize | register/slot、addr、branch、load/store、call slot 参数/返回值、return slot、inline asm moves |
| lower-ops | const/copy/算术/load/store、立即数、类型到 native 助记符、frame-slot |
| call/return | stack-only 参数、outgoing area、返回值 x10、prologue/epilogue、`call-target` |
| machine verify | 无 vreg、无裸 slot、frame/scratch/term 形状、asm-code |
| layout | policy、block order、fallthrough、inline far、函数内 islands、call-target、addr、asm-code、return/trap |
| program layout | 多函数、raw、data、函数/raw/data 偏移、内部 call 近/远、addr 近/远 fallback、data label、data 地址初值 |
| encode | 固定 32-bit native、label 相对偏移、little-endian、call-jal、raw、asm-code、data、section 拼接 |
| driver | source / resolved -> bytes、统一流水线、scratch budget 固定点重试 |
| link | interface source -> externs、address data、relocation、最小 link |
| tests | 24 个测试文件，309 tests passed |

## 5. 当前能表达 / 编译的 IR 子集

- 函数：block + term + vregs + alloc 约束
- 控制流：`jump` / `branch` / `return` / `trap`
- 算术：add/sub/and/or/xor/shift/mul/div/rem 及其 unsigned 变体
- 内存：`load` / `store`，基础宽度和符号
- 地址：局部 `(addr dst ($ x))`、全局 `(addr dst (global chain))`
- 调用：内部函数、stack-only 参数、0/1 返回值
- data：align / label / bytes / fill / value（含地址初值）
- raw：封闭 4 字节 machine 单元，内部 label / 控制转移
- inline asm：显式 inputs / outputs / clobber，封闭 code 块
- layout：函数内 inline far、函数内 islands（无共享/无链）、程序级内部 call relocation
- encode：固定 32-bit、单/多函数、raw、data

## 6. 当前明确不是 SSA

当前 vreg 不是 SSA：

- 同一个 vreg 可以在多个 block 重新定义；
- 没有 phi；
- liveness / allocation 按普通虚拟寄存器变量处理。

这是当前设计的一部分，不是 bug。  
以后是否引入 SSA + phi，是另一层问题；当前流水线不依赖 SSA。

## 7. 主要缺口

### P0：没有它就不算完整后端

已完成：

- **统一 driver**：`driver/compile.rkt` 已把 source / resolved program 跑到 bytes；
- **scratch budget 协商**：`scratch-exhausted` + budget 固定点重试；
- **端到端 source -> bytes**：`test/driver-test.rkt` 覆盖单函数、内部调用、func+raw+data、多文件；
- **interface source / extern / relocation / address data / 最小 link**：
  `link/` 已把外部引用变成 relocation，并用 address data 回填；
  `test/external-test.rkt` 覆盖外部调用、外部 addr、data 地址初值、unresolved/多余地址。

仍缺：

1. **object / ELF / 完整 linker**
   - 没有 object 格式、section 重排、linker relaxation / veneer；
   - 没有入口点 / 初始化 / 运行时启动。

2. **任意 64-bit 全局地址**
   - `addr(global)` 现在只有 PC-relative 和 `lui+addi` fallback；
   - 超出 `lui+addi` 的绝对地址还需要带 scratch 的序列和尺寸模型；
   - 外部地址的 far relocation 也还没有。

### P1：主干有了，但能力不完整

1. **运行时 / ABI**
   - 没有 callee-saved、寄存器参数、tail call、indirect call、varargs、多返回值；
   - 没有异常 / unwind；
   - 没有 heap / GC / stack map 实现，只有设计方向。

2. **islands**
   - 没有共享；
   - 没有 island 链；
   - 没有 mixed island/inline policy；
   - raw / asm-code 内部没有 islands。

3. **asm**
   - 没有显式 memory / scheduling barrier；
   - 没有 tied operand / early-clobber；
   - clobber 与 input/output 重叠在 v1 直接报错。

4. **data**
   - 没有 `reserve` / hole 段；
   - 没有地址减法 / 符号相减；
   - 没有 nested data label / 子段；
   - raw 与 data 还没有统一 section 模型。

5. **raw**
   - 固定 4 字节；
   - 没有 raw 内 relaxation / island；
   - 没有跨 raw / func 跳转；
   - raw 内 pseudo（li/la）不展开。

6. **allocation**
   - 没有 coalescing；
   - 没有 slot sharing；
   - 没有调用点感知 liveness；
   - RV32 下的分配 / spill 还不完整。

7. **layout / target**
   - RVC 关闭；
   - 没有函数对齐 / padding 策略；
   - 没有 section GC / linker relaxation；
   - 没有 target 对象 / extension 选择（xlen 只是参数）。

8. **encode**
   - 只有固定 32-bit；
   - 没有 RVC；
   - 没有对象格式 / relocation 记录。

### P2：质量与工程化

- 错误信息没有 source location；
- 没有 fuzz / property-based test；
- 没有稳定排序 / 诊断快照；
- 没有 CLI / 文件搜索 / 增量编译；
- 没有性能基准；
- 文档和实现还没有完全一一对应到每个 pass。

## 8. 设计上仍需明确的问题

这些问题不是“功能没写”，而是语义/边界还没最终钉死：

1. vreg 是否永远保持非 SSA，还是以后引入 SSA/phi？
2. 调用约定是否长期保持 stack-only，还是计划寄存器参数 / callee-saved？
3. stack map / GC root 的二进制格式和 safepoint 位置。
4. data / raw / func 是否最终统一成 section 模型。
5. 外部符号、relocation、object、linker 的最小模型。
6. target 何时从 `#:xlen` 参数变成正式 target 对象。
7. RVC 引入后，layout 的 2/4 字节尺寸和 island/range 模型如何统一。
8. 是否允许 layout 自动拆块（当前明确：不允许，直接报错）。

## 9. 建议的下一步顺序

先把“完整后端主干”闭合，再补能力：

1. 任意 64-bit 全局地址 / 外部 far relocation；
2. object / ELF / 完整 linker；
3. islands 共享 / 链 / mixed policy；
4. 运行时契约：stack map / GC roots / callee-saved / 参数寄存器化；
5. RVC / RV32 / target 对象；
6. 优化：coalescing、slot sharing、section GC。

## 10. 当前结论

现在的主干已经能证明：

- IR 形状和层边界是可行的；
- allocation / materialize / layout / encode 的职责可以分开；
- 内部调用、data、raw、inline asm、islands 都有可运行的闭环。

统一 driver、端到端 source -> bytes、最小 link 已经补上。  
距离“完整后端”现在主要还差：

```text
完整 linker / object 格式 / relaxation
运行时契约
```

在这两件补齐之前，功能可以继续加，但系统还不能算完整。
