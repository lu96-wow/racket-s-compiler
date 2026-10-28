> **注意**：本文的 C activation / SysV 部分只作为 Layer 0 bootstrap。
> 新目标见 `FASM.md`：汇编 -> 函数式汇编（F-asm）-> Scheme，不兼容 C。

# riscv-compiler 设计指导书（底层算法链）

> 骨架总览见 `SKELETON.md`。本文记录当前最小实现和算法细节。

## 1. 当前方向

当前不是先做 C-like 前端，而是从底层 S-expression 汇编往上搭算法层：

```text
手写 vreg asm
  -> CFG
  -> block 分支分析与优化
  -> 重建 CFG
  -> liveness
  -> interference graph
  -> 图着色寄存器分配
  -> layout / 跳转地址
  -> 顶层 S-expression
```

目标是先得到一个**可行的 S-expression 变换框架 + 最简算法**。  
前端、栈帧、spill、调用约定以后再加。

顶层 S-expression 的具体形状不重要。  
重要的是每个阶段的输入/输出数据、算法和替换关系都显式、可打印、可测试。

---

## 2. 核心原则

1. 每个阶段都是纯函数或显式数据变换。
2. 中间结果统一是 S-expression。
3. label、vreg、物理寄存器在数据里始终可区分。
4. 所有会增删指令的优化都必须放在 layout 之前。
5. label 地址解析放最后。
6. 第一版不做 spill；分不到颜色直接报错。

---

## 3. 文件结构

```text
riscv-compiler/
  DESIGN.md
  main.rkt              CLI
  compile-asm.rkt       底层主链组合（纯 asm / frame 两条入口）
  asm.rkt               汇编 S-expr 判断
  frame.rkt             frame / env / cont / call 形式层
  repr.rkt              表示类型 / 结构体布局 / 字面值编码
  literal-lower.rkt     const -> addi
  lower-frame.rkt       frame + env lowering + prologue
  call-lower.rkt        call / tailcall / return lowering + epilogue
  regalloc-cache.rkt    缓存式寄存器分配实验
  sets.rkt              集合工具
  cfg.rkt               basic block + CFG
  branch-opt.rkt        block 分支分析/优化
  liveness.rkt          use/def + live-in/live-out
  interference.rkt      interference graph
  regalloc-graph.rkt    图着色寄存器分配
  layout.rkt            label 地址和跳转偏移
  program.rkt           顶层 S-expression 组装
  examples/
    basic-asm.sexpr
  test/
    core-test.rkt
  Makefile
```

`riscv-help` 只作为底层工具库使用：

- `fits-branch?`
- `fits-jal?`

---

## 4. 数据契约

### 4.1 asm

```racket
(asm
  (label main)
  (addi v0 x0 0)
  (addi v1 x0 1)
  (bge v0 v1 L0)
  ...)
```

指令：

```racket
(mnemonic operand ...)
```

寄存器：

- vreg：`v0`、`v1`、...
- 物理寄存器：`a0`、`t0`、`ra`、...
- label：`main`、`L0`、...

### 4.2 cfg

```racket
(cfg
  (blocks
    (block B0
           (labels (main))
           (insns ((addi v0 x0 0)
                   ...)))
    ...)
  (label-map
    ((main . B0)
     (L0 . B2)
     ...))
  (succ
    ((B0 B2 B1)
     (B1 B3)
     ...)))
```

规则：

- 函数入口、label、terminator 后第一条指令是 leader。
- label 归属下一个 block。
- `branches` 有 target 和 fallthrough 两个后继。
- `(jal x0 L)` 只有 target。
- `(jalr x0 ra 0)` 没有后继。
- 其他 `jalr` 暂时按 fallthrough 处理。

### 4.3 liveness

```racket
(liveness
  (B0
    (use ())
    (def (v0 v1))
    (in (ra))
    (out (ra)))
  ...)
```

公式：

```text
out[B] = union(in[S] for S in succ(B))
in[B]  = use[B] union (out[B] - def[B])
```

### 4.4 interference

```racket
(interference
  (a0 ra)
  (ra a0 v0 v1 v2 v3 v4)
  (v0 ra v1)
  ...)
```

每项：

```racket
(node neighbor ...)
```

规则：

- 对每条定义 `d`，把 `d` 与指令 live-out 中的每个寄存器连边。
- `x0` 不参与 use/def。
- 物理寄存器也参与 interference。

### 4.5 coloring

```racket
(coloring
  ((a0 . a0)
   (ra . ra)
   (v0 . t1)
   (v1 . t0)
   ...))
```

### 4.6 layout

```racket
(layout
  (labels
    ((main . 0)
     (L0 . 24)
     (L1 . 32)))
  (code
    (addi t1 x0 0)
    (bge t1 t0 16)
    (jal x0 12)
    ...))
```

规则：

- 每条指令 4 字节。
- label 不占空间。
- branch/jal 目标替换为 `target - pc`。
- 使用 `riscv-help` 检查 `fits-branch?` / `fits-jal?`。

### 4.7 顶层 program

```racket
(program
  (func main
        (labels ...)
        (code ...)))
```

---

## 5. 算法层

### 5.1 CFG

实现位置：`cfg.rkt`

输出：

- `blocks`
- `label-map`
- `succ`

当前 block 划分：

- 遇到 label 开始新 block
- 遇到 terminator 结束当前 block
- 空 fallthrough block 也保留

### 5.2 branch-opt

实现位置：`branch-opt.rkt`

输入：CFG  
输出：优化后的 asm

当前规则：

1. 删除不可达 block。
2. 如果无条件跳转的目标 block 就是下一个 block，删除该跳转。

branch-opt 之后必须重建 CFG，因为 block 结构和 succ 可能已改变。

### 5.3 liveness

实现位置：`liveness.rkt`

当前支持的指令：

- `addi` / `addiw` / `slti` / `sltiu` / `xori` / `ori` / `andi`
- `add` / `sub` / `sll` / `slt` / `sltu` / `xor` / `srl` / `sra` / `or` / `and`
- `addw` / `subw` / `sllw` / `srlw` / `sraw`
- `slli` / `srli` / `srai` / `slliw` / `srliw` / `sraiw`
- `lui` / `auipc`
- B-type branch
- `jal`
- `jalr`

遇到未知指令直接报错，不静默猜测。

### 5.4 interference

实现位置：`interference.rkt`

从 `cfg` + `liveness` 建立邻接表。

所有 vreg 都会出现在图里，即使没有边。

### 5.5 图着色寄存器分配

实现位置：`regalloc-graph.rkt`

当前策略：

- 物理寄存器预着色。
- 安全颜色池：
  ```text
  t0..t6, s0..s11, a1..a7
  ```
- `a0`、`ra`、`sp`、`gp`、`tp`、`x0` 不作为普通 vreg 的颜色。
- simplify / select。
- 不做 spill；分不到颜色直接报错。

### 5.6 layout

实现位置：`layout.rkt`

- 第一遍收集 label 地址。
- 第二遍替换 branch/jal 目标为数值偏移。
- 检查范围。
- 输出 label 表和 resolved code。

### 5.7 输出

实现位置：`program.rkt`

只负责收集：

```racket
(program
  (func name
        (labels ...)
        (code ...)))
```

---

## 6. 当前示例

输入：`examples/basic-asm.sexpr`

```racket
(asm
  (label main)
  (addi v0 x0 0)
  (addi v1 x0 1)
  (bge v0 v1 L0)
  (addi v2 x0 42)
  (addi v3 v2 0)
  (jal x0 L1)
  (label L0)
  (addi v4 x0 7)
  (addi v3 v4 0)
  (label L1)
  (addi a0 v3 0)
  (jalr x0 ra 0))
```

当前图着色结果：

```racket
((v0 . t1)
 (v1 . t0)
 (v2 . t0)
 (v3 . t0)
 (v4 . t0))
```

layout：

```racket
((main . 0)
 (L0 . 24)
 (L1 . 32))
```

最终：

```racket
(program
 (func main
       (labels ((main . 0)
                (L0 . 24)
                (L1 . 32)))
       (code
        (addi t1 x0 0)
        (addi t0 x0 1)
        (bge t1 t0 16)
        (addi t0 x0 42)
        (addi t0 t0 0)
        (jal x0 12)
        (addi t0 x0 7)
        (addi t0 t0 0)
        (addi a0 t0 0)
        (jalr x0 ra 0))))
```

---

## 7. 运行

```bash
cd racket-s-compiler/riscv-compiler
racket main.rkt examples/basic-asm.sexpr
racket main.rkt --verbose examples/basic-asm.sexpr
```

测试：

```bash
make test
```

当前：

```text
13 tests passed
```

---

## 8. 当前限制

- 没有 spill。
- 没有栈帧。
- 没有函数调用约定。
- 没有多函数。
- 没有源语言前端。
- 没有压缩指令。
- 没有链接松弛。
- 没有机器码编码。
- `jal` 调用目标必须存在于当前 asm。
- 只支持 32 位有符号范围内的 branch/jal。

---

## 9. 后续方向

1. spill：分不到颜色时插入 load/store。
2. 栈帧：slot 分配、prologue/epilogue。
3. 调用约定：参数、返回值、caller/callee-saved。
4. 更完整的 branch analysis：
   - block 合并
   - 分支反转
   - 空块删除
5. 变量 location 抽象：
   - `(stack slot)`
   - `(heap depth index)`
6. heap-linked frame 实验。
7. 源码 S-expression 前端，放到独立 `frontend/`。
8. 最终编码/后端 S-expression 消费。
