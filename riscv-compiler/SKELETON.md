# riscv-compiler 骨架记录

代码只是这个骨架的一个最小参考实现。  
真正要保留的是下面这套**分阶段 S-expression 变换模型**。

---

## 1. 核心想法

```text
编译器 = 一串显式的 S-expression 变换
```

每个阶段：

```text
stage: S-expression -> S-expression
```

不允许隐藏状态直接改内部 IR。  
每个阶段都应该：

- 输入可打印
- 输出可打印
- 可以单独测试
- 用显式替换表完成符号替换

---

## 2. 两个世界

### 符号世界

```text
label : main, L0, L1
vreg  : v0, v1, v2
slot  : slot0, slot1
```

### 具体世界

```text
物理寄存器 : a0, t0, s0, ra
offset     : 8, -16
地址       : 0x1000
```

布局、寄存器分配、栈帧都只负责把符号世界往具体世界推进一步。

---

## 3. 当前主链

```text
手写 vreg asm
  -> CFG
  -> branch-opt
  -> 重建 CFG
  -> liveness
  -> interference graph
  -> 图着色寄存器分配
  -> layout / 跳转地址
  -> 顶层 S-expression
```

对应阶段：

```text
asm
  -> cfg
  -> asm
  -> cfg
  -> liveness
  -> interference
  -> asm + regmap + coloring
  -> labels + resolved code
  -> program
```

---

## 4. 未来完整主链

```text
源 S-expression
  -> 语法校验 / 规范化
  -> core AST
  -> 三地址 IR
  -> 指令选择
  -> vreg asm
  -> CFG
  -> branch-opt
  -> liveness
  -> interference
  -> 图着色寄存器分配
  -> spill
  -> 栈帧 / context
  -> 调用约定 lowering
  -> layout
  -> relocation / encoding
  -> 后端消费的 S-expression
```

上层语言以后接在 `vreg asm` 之前。  
下层编码以后接在 `layout` 之后。

---

## 5. 中间数据形状

### asm

```racket
(asm
  (label main)
  (addi v0 x0 0)
  (bge v0 v1 L0)
  ...)
```

### cfg

```racket
(cfg
  (blocks
    (block B0
           (labels (main))
           (insns (...)))
    ...)
  (label-map ((main . B0) ...))
  (succ ((B0 B2 B1) ...)))
```

### liveness

```racket
(liveness
  (B0
   (use ...)
   (def ...)
   (in ...)
   (out ...))
  ...)
```

### interference

```racket
(interference
  (v0 ra v1)
  (v1 ra v0)
  ...)
```

每项：

```racket
(node neighbor ...)
```

### regmap / coloring

```racket
((v0 . t1)
 (v1 . t0)
 ...)
```

```racket
(coloring
  ((v0 . t1)
   (ra . ra)
   ...))
```

### layout

```racket
((labels ((main . 0) (L0 . 24) ...))
 (code ((addi t1 x0 0) (bge t1 t0 16) ...)))
```

### 顶层 program

```racket
(program
  (func main
        (labels ...)
        (code ...)))
```

顶层形状不重要，它只是容器。

---

## 6. 替换表

整个骨架主要靠这几张表推进：

| 表 | 作用 |
| --- | --- |
| `label-map` | label -> block |
| `liveness` | block -> use/def/in/out |
| `interference` | node -> neighbors |
| `regmap` | vreg -> physical register |
| `coloring` | node -> physical register |
| `labels` | label -> byte address |
| `slot-map`（未来） | slot -> frame offset |
| `location-map`（未来） | local -> stack/heap/reg |

所有 pass 的模式都应该是：

```text
计算替换表
-> 统一 rewrite
```

而不是每个 pass 手写一套遍历逻辑。

---

## 7. 不可破坏的规则

1. **label 尽量晚解析。**
2. **vreg 一直保留到寄存器分配。**
3. **slot 一直保留到 frame offset 分配。**
4. **所有会增删指令的阶段都在 layout 之前。**
5. **branch-opt 之后必须重建 CFG。**
6. **图着色第一版不 spill，分不到颜色直接报错。**
7. **物理寄存器预着色，安全颜色池显式列出。**
8. **未知指令直接报错，不静默猜测 use/def。**
9. **每个阶段输出都必须是可打印 S-expression。**
10. **顶层形状可以改，中间数据契约不要随便改。**

---

## 8. 和 LLVM / GAS 的关系

宏观顺序更像 LLVM 编译器后端：

```text
CFG -> machine passes -> liveness/regalloc -> frame -> layout
```

不像 GAS：

- GAS 是汇编器
- 没有 CFG
- 没有 liveness
- 没有寄存器分配
- 主要做宏展开、fixup、layout、relocation

我们的 layout 对应 GAS / LLVM MC 的 assembler layout。  
但当前是最简单版本：

- 固定 4 字节
- 单遍布局
- 不收缩
- 不松弛

未来加压缩/长分支后，layout 要变成不动点迭代。

---

## 9. 上层语言接入点

上层语言不要直接生成物理寄存器，也不要直接算地址。

前端最终只生成：

```racket
(asm
  (label main)
  (addi v0 x0 0)
  (bge v0 v1 L0)
  ...)
```

前端负责：

- 源 S-expression 解析/校验
- 作用域和变量解析
- 表达式/语句 lowering
- 生成确定性 label
- 生成 vreg
- 生成 `(asm ...)`

前端不负责：

- 物理寄存器分配
- 栈帧 offset
- label 地址
- 跳转偏移
- 机器码

未来前端骨架：

```text
源 S-expression
  -> core AST
  -> 规范化
  -> 三地址 IR
  -> 指令选择
  -> vreg asm
  -> 进入当前底层链
```

---

## 10. 未来变量位置模型

当前：

```text
local -> vreg -> physical register
```

未来：

```text
local -> location
location = (stack slot) | (heap depth index) | (reg vreg)
```

指令选择只生成：

```racket
(load-local x)
(store-local x v)
```

location lowering 再决定：

```text
sp + offset
frame-pointer + offset
```

这样以后可以从栈模型扩展到 heap-linked frame，而不重写前面的阶段。

---

## 11. 当前最小实现边界

已实现：

- asm S-expression
- CFG
- branch-opt：不可达 block、跳转到下一块
- liveness
- interference graph
- 图着色寄存器分配（无 spill）
- layout
- 顶层 S-expression

未实现：

- 源语言前端
- spill
- 栈帧
- 调用约定
- 多函数
- 压缩指令
- 链接松弛
- relocation
- 机器码编码

---

## 12. 一句话总结

> 保留骨架，不保留复杂度。  
> 新功能只往阶段之间插 pass，不推翻 S-expression 变换模型。
