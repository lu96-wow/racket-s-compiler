# target（`target.rkt`）

## 作用

记录 amd64 的目标事实：架构、指针宽度、特性集合，以及填充策略。target 是显式参数，
没有全局 `current-target`。

## 数据模型

```racket
(struct target (arch pointer-width features) #:transparent)

(define target-amd64 (target 'amd64 64 '()))
```

当前只支持 64 位；`features` 留作后续能力开关。端序固定 little，不放进 target。

## 相关 s-exp / 函数

| 名字 | 作用 |
| --- | --- |
| `integer->bytes width value` | 整数 -> width 个小端字节 |
| `padding-bytes target kind n` | code 用 `0x90` NOP，data 用 0 |
| `target-64? target` | 当前编码器只接受 64 位 mode |
| `layout-program` / `relax` / `encode-layout` | 显式接收 target |
| `bind-labels` | 不需要 target |

## 填充

- code：1 字节 NOP `0x90`，任意长度都可补。
- data：0。
- 没有 16/32 位模式；也没有 RISC-V 那种 2 字节压缩 NOP 的限制。

## 不放进 target

操作数语法、段/place、ABI/栈、寄存器分配、reloc/loader。
