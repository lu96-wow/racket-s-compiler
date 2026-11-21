# call / return lowering 与 runtime contract

本文设计没有 C ABI 的内部调用约定。目标是：

- 第一版简单、统一；
- 和 stack-first 内存模型一致；
- backend 仍然只 encode；
- 以后可以加寄存器参数、callee-saved、tail call，而不改 core IR。

实现：

```text
ir/call-plan.rkt   统计 outgoing args / scratch demand
ir/call-lower.rkt  prologue / call sequence / return sequence
layout-relax       函数内：call-target 先保留，return -> jalr
layout/program.rkt 程序级：函数偏移、call-target -> call-jal / auipc+jalr
```

测试：`test/call-plan-test.rkt`、`test/call-lower-test.rkt`、
`test/layout-program-test.rkt`。

当前已实现：

- prologue / epilogue；
- 参数写 outgoing area；
- `(call ...)` -> `(call-target (global ...))`；
- 返回值移动；
- `(term (return ...))` -> epilogue + `(term (return))`；
- 大 frame 用第二 scratch；
- outgoing 不足、scratch 不足、fixed scratch、多个返回值显式报错；
- 程序级 `call-target` 解析：近调用 `jal x1, delta`，远调用 `auipc x1, hi` + `jalr x1, x1, lo`；
- materialize 支持 call 的 slot 参数 / slot 返回值；
- call-lower 选择 scratch 时避开 call 参数寄存器，避免覆盖 materialize 预加载的值；
- 函数级 encode 仍然拒绝未解析的 `call-target`。

## 1. 第一版约定

| 项 | 决定 |
| --- | --- |
| 参数 | 全部走调用者的 outgoing stack area |
| 参数大小 | 每个参数一个 XLEN slot |
| 返回值 | 0 / 1 个，放 x10 |
| return address | x1 |
| stack pointer | x2 |
| frame pointer | x8 |
| callee-saved | 第一版没有；除 x1/x2/x8 外全部 caller-saved |
| 调用者清理 | 不清理；outgoing area 在调用者帧里固定预留 |
| frame 对齐 | 16 字节 |
| 栈方向 | 向下增长 |

为什么第一版全走栈：

- 和 stack-first 一致；
- 不需要参数寄存器分配；
- varargs / GC roots / 多返回值以后更容易扩展；
- call 降级逻辑简单；
- 寄存器参数可以以后作为优化加，不影响 core IR。

代价是更多 load/store。第一版先保证语义和边界清楚。

## 2. 帧与参数位置

```text
高地址
+----------------------+
| 调用者帧              |
+----------------------+
| 调用者 outgoing args |  <- callee FP
+----------------------+
| saved RA             |  FP - 8
| saved old FP         |  FP - 16
| callee slots         |  FP - ...
| callee outgoing args |  SP ...
+----------------------+  <- callee SP
低地址
```

- caller 在 `SP + i * word` 写入第 i 个参数；
- callee 在 `FP + i * word` 读第 i 个参数；
- `word = XLEN / 8`；
- outgoing args 区由 caller 的 frame-layout 固定预留；
- 调用前后 `SP` 不变；callee 自己负责分配/释放自己的 frame。

## 3. call-plan

`call-plan` 只扫描 machine IR，不生成代码：

```racket
(call-plan func #:xlen 64)
;; => (call-plan
;;      (max-args n)
;;      (outgoing-size bytes)
;;      (scratch-demand n))
```

职责：

- 找 `(call dst (global f) arg ...)`；
- 统计最大参数个数；
- 计算 `outgoing-size = align(max-args * word, 16)`；
- 估算 call lowering 需要的 scratch；
- 多返回值在 `call-plan` 里拒绝；非 `(global chain)` 的 call target 在
  `verify` 里拒绝（`call` 只支持直接调用，indirect call 还没有）。

`frame-layout` 使用 `outgoing-size`：

```racket
(frame-layout func allocation #:outgoing-size outgoing-size)
```

## 4. prologue

call lowering 在 entry block 最前面插入 prologue。

需要至少 1 个 scratch `t`：

```scheme
(addi t  fp 0)                  ; 保存 old FP
(addi fp sp 0)                  ; FP = caller SP
(addi sp sp -frame-size)        ; frame-size 在 s12 内
(sd ra -8(fp))                  ; 保存 return address
(sd t -16(fp))                  ; 保存 old FP
```

`frame-size` 超出 s12 时：

```scheme
(li t2 frame-size)
(sub sp sp t2)
```

需要第 2 个 scratch。

注意：

- `FP` 在调整 `SP` 之前设置；
- `FP` 指向 caller 的 `SP`，所以 incoming args 在 `FP + offset`；
- RA / old FP 用 FP 相对负偏移保存，避免 frame-size 影响保存偏移；
- 第一版不保存 callee-saved 寄存器。

## 5. call sequence

对：

```scheme
(call dst (global f) arg ...)
```

### 5.1 写参数

每个参数写入 caller 的 outgoing area：

```scheme
(sd arg0 0(sp))
(sd arg1 8(sp))
...
```

- 参数是 native/scratch 寄存器：直接 `sd`；
- 参数是整数：先 `li scratch, value`，再 `sd`；
- 参数是 global：等地址模型；
- 参数是 slot 值：由 materialize 先 load 到 scratch；call-lower 随后
  不能把这个 scratch 当作自己的临时寄存器；
- offset 超出 s12：用 scratch 算地址，再 `sd 0 scratch`。

### 5.2 调用

call lowering 先发一个 machine pseudo：

```scheme
(call-target (global f))
```

由 program-layout 选择最终形式：

```scheme
(jal x1 delta)                  ; 在 JAL 范围内
;; 或
(auipc x1 hi)
(jalr x1 x1 lo)                 ; far call，不需要 scratch
```

函数内 layout-relax 先把它保留为 8 字节的符号形式；program-layout 再根据
函数起始偏移决定近/远形式。

`auipc x1` + `jalr x1, x1, lo` 是合法的：`jalr` 先读 rs1，再写 rd=x1，
返回地址是 `jalr` 的下一条指令。

### 5.3 取返回值

第一版只有一个返回值，放在 x10：

```scheme
(addi dst x10 0)                ; dst != x10
```

- `dst` 是 x10 时省略；
- `dst` 在 slot 时，materialize 已经用 scratch 中转并在 call 后 store；
- 没有返回值时，x10 内容未定义，调用方不应使用。

## 6. return sequence

对：

```scheme
(term (return operand ...))
```

### 6.1 返回值

- 0 个 operand：不移动；
- 1 个 operand：移动到 x10；
  - operand 是 x10：省略；
  - operand 是整数：`li x10 value`；
- 2 个 operand：以后用 x10 / x11；
- 多于 2：显式报错。

### 6.2 epilogue

需要 1 个 scratch `t`：

```scheme
(ld ra -8(fp))
(ld t -16(fp))                  ; old FP
(addi sp fp 0)                  ; SP = caller SP
(addi fp t 0)                   ; 恢复 old FP
```

然后 term 变成：

```scheme
(term (return))
```

layout-relax 把 `(term (return))` 展开为：

```scheme
(jalr x0 x1 0)
```

### 6.3 多个 return

每个 return term 都插入同样 epilogue。  
以后可以 tail merge epilogue；第一版不优化。

## 7. lowered machine forms

call lowering 之后允许出现：

```scheme
(call-target (global chain))
(term (return))
```

含义：

- `call-target`：参数已经写到 outgoing area，返回值在 x10；最终 b/j 形式由 layout 选。
- `(term (return))`：返回值已经放到 x10，frame 已经恢复；最终 `jalr x0, x1, 0` 由 layout/encode 选。

不允许：

- `(call-target ...)` 出现在 layout 之后；
- `(term (return))` 出现在 layout 之后还带 operand；
- `call` 原始形式出现在 call lowering 之后。

## 8. layout 的责任

函数内 `layout-relax` 负责：

- `(term (return))` -> `jalr x0, x1, 0`；
- 条件分支 -> `beq/bne/blt/bge/bltu/bgeu`；
- `jump` / `branch` 的 fallthrough / 反向 / far / island；
- 不改参数/返回值移动；
- `call-target` 暂时保留，按 8 字节预留。

程序级 `layout/program.rkt` 负责：

- 函数顺序和起始偏移；
- `(call-target (global f))` -> 近 `jal` 或远 `auipc+jalr`；
- 迭代到尺寸固定点；
- 目标函数必须在同一程序里。

call lowering 不负责远跳/范围判断。

## 9. stack map / GC roots

第一版约束：

- 所有调用都把除 x1/x2/x8 外的寄存器视为 clobbered；
- 活着的指针值在 call site 前应该已经在 stack slot 里；
- caller 的 stack map 标记：
  - live pointer slots（FP 相对）；
  - outgoing pointer args（SP 相对）；
- callee 的 incoming args 在 `FP + offset`，由 caller 的 call-site map 覆盖；
- callee 如果把 incoming pointer 长期保存在自己的 frame/寄存器里，自己的 stack map 也要标记。

以后可以：

- callee-saved 寄存器；
- 寄存器 root mask；
- precise liveness stack map；
- tail call / call-cc 的栈处理。

## 10. scratch demand

第一版 call lowering 可能需要的 scratch：

| 场景 | scratch |
| --- | --- |
| prologue 保存 old FP | 1 |
| frame-size 超出 s12 | +1 |
| 参数是整数 | 1 |
| outgoing offset 超出 s12 | 1 |
| return 值是整数 | 0（直接 li x10） |
| epilogue 恢复 old FP | 1 |

prologue 和 epilogue 不嵌套，可以复用。  
一个 call site 最多同时需要 2 个 scratch。

策略 B 的 budget 要把 call lowering 的需求算进去。

## 11. 暂不支持

- 寄存器参数；
- callee-saved 寄存器；
- 多个返回值（>1）；
- tail call；
- indirect call / 函数指针；
- varargs / 多值返回区；
- `call/cc`；
- 异常 / unwind；
- RVC。

这些以后加，不改变 core IR 的 `call` / `return` 语义。

## 12. 需要以后决定

- 多返回值用 x10/x11 还是 caller-provided return area；
- tail call 的 frame reuse 规则；
- `call/cc` 用栈复制还是 heap frame；
- callee-saved 集合和保存点；
- stack map 的二进制编码；
- 参数寄存器化何时引入；
- indirect call 的 IR 形状。
