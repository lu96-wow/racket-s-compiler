# 内存与栈模型

本文固定第一版内存模型。目标是：先用栈把语义跑通，再逐步把不逃逸的值提升到寄存器。

> **第一版 stack-first：可寻址/可变的变量住栈；表达式临时值住 vreg。**  
> **目标架构 hybrid：不逃逸、不取地址的变量以后从栈提升到 vreg；捕获/逃逸的变量进堆。**

## 1. 核心原则

1. **`addr` 必须显式写。** 没有隐式的“取局部变量地址”或隐式 local load/store。
2. **栈是 LIFO region，不是特殊 GC。** 返回即释放；GC 只把栈帧当 roots 扫描。
3. **堆是 GC 区。** 捕获/逃逸/共享对象进堆；第一版用 precise、non-moving GC。
4. **寄存器是表达式临时值的家。** 栈上变量的寄存器只是缓存，不是语义位置。
5. **不照搬 C ABI。** 但生成代码和 runtime 必须共享一套显式 runtime contract。
6. **值的位置由身份/生命周期决定，不由 allocator 决定。**

## 2. 存储类

| 值 | 存储类 | 说明 |
| --- | --- | --- |
| 表达式临时值 | vreg -> 物理寄存器 | 无地址、短生命周期 |
| 可变/可寻址的局部变量 | stack slot | 第一版默认全部上栈 |
| 不逃逸、不取地址的局部变量 | 以后提升为 vreg | 第二版优化 |
| 被闭包/continuation 捕获 | heap cell | closure conversion 处理 |
| 模块级 | global data | `data` |
| 常量 | immediate / constant pool | 无存储 |

判定规则：

- 被 `addr` 取地址 -> 必须有稳定内存位置；
- 被闭包/continuation 捕获 -> heap；
- 只在当前函数内、不取地址、不逃逸 -> 可以 vreg；
- 活过当前帧 -> heap（或调用者提供的区域）。

## 3. 第一版怎么表达“变量在栈上”

不新增内存 IR。直接使用已有的：

1. 可变局部变量声明为 `(address-taken)` vreg；
2. 访问变量先 `(addr ($ p) ($ x))`，再 `load` / `store`；
3. allocation 强制 `(address-taken)` 的 vreg 落到 `(slot n)`；
4. materialize 把 `(addr ($ p) ($ x))` 变成 frame 地址；
5. frame-layout 把 slot 变成 `FP - offset`。

materialize 后仍然保留显式地址操作：

```scheme
;; virtual
(addr ($ p) ($ x))

;; machine
(addr (native x10) (frame-slot 0))
```

不存在“隐式取局部变量地址”或“隐式 local load/store”。

例子：

```scheme
(vregs
  (($ x) (b64) (address-taken))
  (($ p) (ptr))
  (($ t) (b64)))

(block b0
  (addr ($ p) ($ x))
  (store ($ p) 0 ($ t) (b64))
  ...)
```

`($ x)` 是变量，稳定在栈上；`($ t)` 是表达式临时值，走着色。

以后加 `promote-locals`：

- 没有 `addr`；
- 没有被闭包捕获；
- 不跨调用存活；
- 删掉 `(address-taken)` 和 load/store，把变量变成普通 vreg。

## 4. 栈帧布局

向下增长，16 字节对齐：

```text
高地址
+----------------------+
| 调用者帧              |
+----------------------+
| 调用者的 outgoing args|  <- callee 的 FP
+----------------------+
| saved RA             |  FP - 8
| saved old FP         |  FP - 16
| saved callee regs    |  FP - 24 ...（header 加大时才有）
| spill slots          |  FP - ...
| address-taken locals |  FP - ...
| outgoing args        |  SP ...
+----------------------+  <- 当前 SP
低地址
```

约定：

- `SP` 指向当前帧最低地址，始终 16 字节对齐；
- `FP` 指向调用者的 SP，也就是当前帧高地址边界；
- `slot offset` 是 **FP 到 slot 低地址的距离**：地址 = `FP - offset`；
- `header` 默认 16 字节：saved RA + saved old FP；
- 如果 prologue 要保存 callee-saved 寄存器，就把 `header-size` 加大，
  额外空间仍然在 slots 之前；第一版 frame-layout 默认不分配 callee-saved 区；
- callee 的 incoming stack args 在 `FP + offset`；
- 调用者在自己帧底部预留最大 outgoing args 区；
- 叶子函数以后可以省略 saved RA；第一版统一保存；
- frame size 包含 header、slot、outgoing args 和 padding，最后按 16 对齐。

## 5. frame 形状

`frame-layout` 输出：

```scheme
(frame
  (size 48)
  (header 16)
  (outgoing 0)
  (align 16)
  (slots
    (slot 0 (offset 17) (size 1) (align 1))
    (slot 1 (offset 40) (size 8) (align 16))
    (slot 2 (offset 44) (size 4) (align 4))))
```

规则：

- slot 按 slot index 升序放置；
- 多个 vreg 共享同一个 slot 时，取最大 size / align；
- slot 的 size / align 来自 vreg 类型和 `(align n)` option；
- `(b8)` / `(s8)` = 1，`(b16)` / `(s16)` = 2，`(b32)` / `(s32)` = 4，
  `(b64)` = 8，`(ptr)` = XLEN / 8；
- `frame-slot-offset` 是唯一查偏移的方式，不在别处重复算。

已实现：[`ir/frame.rkt`](ir/frame.rkt)。测试：[`test/frame-test.rkt`](test/frame-test.rkt)。

## 6. Runtime contract

不遵循 C ABI，但必须有内部约定。第一版：

| 用途 | 寄存器 / 位置 |
| --- | --- |
| zero | x0 |
| return address | x1 |
| stack pointer | x2 |
| frame pointer | x8 |
| 参数 | 全部走 caller 的 outgoing stack area |
| 返回值 | x10（第一版只支持 0/1 个） |
| callee-saved | 第一版没有；除 x1/x2/x8 外全部 caller-saved |
| scratch | 由 allocation reserve / output |

规则：

- 参数按 XLEN slot 写在 `SP + i * word`；callee 从 `FP + i * word` 读；
- 返回值走 x10，多返回值以后可以 x10/x11；
- 第一版 prologue 用 scratch 保存 old FP；
- `clobber` 进入 allocation；第一版 call 点 clobber 除 x1/x2/x8 外的寄存器；
- `pin` / `reserve` 仍然有效；
- 这套 contract 可以整体替换，不影响 virtual IR。

详细设计见 [`CALL.md`](CALL.md)。

## 7. Stack map 与 GC roots

- 栈帧是 GC roots，但不是 GC 对象；
- 每个函数有一张 stack map，按 safepoint（调用/分配）记录：
  - 哪些 `FP - offset` slot 里是活指针；
  - 哪些寄存器里是活指针；
- GC 通过 saved FP 链遍历栈帧，用 saved RA 找对应 stack map；
- 第一版可以要求“所有 live pointer 在 safepoint 前落到 stack slot”，
  这样 stack map 只需要 slot 列表；以后再加寄存器 mask。

## 8. 堆与 GC

第一版：

- heap 是 precise、non-moving mark-sweep；
- 对象有 header：类型、大小、mark bit；
- 闭包/环境/可变捕获变量在 heap；
- 栈上的指针指向 heap；heap 不指向栈（逃逸对象必须已提升）；
- 分配慢路径进入 runtime；
- GC 扫描栈 roots、寄存器 roots、全局 roots。

以后：

- moving GC / semi-space；
- escape analysis：不逃逸的 heap 对象提升到栈；
- stack promotion / region；
- `call/cc` 的栈复制或 heap frame。

## 9. 为什么不是“全变量内存 + 寄存器 cache”

- load/store 会包围每条 op；
- 需要 load/store 消除、别名分析、缓存分配；
- 图着色变成 cache coloring；
- 整体并不更简单，优化空间更小。

第一版 stack-first 已经把可变变量放栈，但表达式临时值仍走 vreg，不会退化成纯内存机器。

## 10. 为什么不是“栈当特殊 GC”

- 栈是 LIFO region，返回即释放；
- 把栈帧变成 GC 对象会引入 header、barrier、逃逸提升、stack map、call/cc 复杂度；
- 栈本来就不需要被“回收”，LIFO 已经是最简单的回收策略。

所以：**栈是 region，堆是 GC，escape analysis 是桥。**

## 11. 未定问题

- 是否支持 `call/cc`；如果支持，用栈复制还是 heap frame；
- 尾调用是否必须；
- moving GC 何时引入；
- 多返回值 / varargs / 异常；
- stack map 的具体编码和查找方式；
- xlen 最终固定为 32 还是 64；
- leaf function 是否省略 saved RA；
- slot sharing 的 liveness 检查由哪个 pass 保证。
