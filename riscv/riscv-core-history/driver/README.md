# driver

统一驱动：source / resolved program -> encoded bytes。

## 入口

```racket
(require "driver/compile.rkt")

(compile-source forms
                #:policy default-layout-policy
                #:xlen 64
                #:origin 0
                #:forbidden runtime-forbidden
                #:max-scratch 31)
;; => compiled-program

(compile-files files #:interface-files interface-files ...)
(compile-resolved-program resolved-program ...)
```

`compiled-program`：

```racket
(struct compiled-program
  (bytes
   layout
   encoded
   exports
   scratch-budget))
```

## 流水线

```text
frontend
  -> allocate
  -> materialize
  -> call-plan
  -> frame-layout
  -> lower-ops
  -> call-lower
  -> machine verify
  -> layout-program
  -> encode-program
```

## scratch budget

第一版采用固定点重试：

```text
budget = 0
loop:
  try compile
  if scratch-exhausted:
    if budget < max-scratch: budget += 1; retry
    else: raise
```

不足由 `ir/scratch.rkt` 的 `scratch-exhausted` 统一表示。  
每次 budget 增加都会重跑整个 program；这是策略 B 的最小可用版本。

## runtime forbidden

`runtime-forbidden` 默认：

```scheme
((native x1) (native x2) (native x8) (native x10) (native x11))
```

普通分配和 scratch 都不会使用这些寄存器。

## 当前边界

- 每个函数独立跑 allocation / materialize / call-lower；
- data / raw 不经过函数流水线；
- 最后统一进入 `layout-program` / `encode-program`；
- interface source 只提供 extern 表；外部地址由 `link/` 的 address data 提供；
- 没有增量编译 / 文件缓存。
