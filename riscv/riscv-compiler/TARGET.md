# target

## 数据模型

```racket
(struct target (xlen extensions) #:transparent)
```

- `xlen`：`'rv32 | 'rv64`
- `extensions`：已排序、无重复的 symbol 列表
- 端序固定 little，不放进 target

## Profile

```racket
target-rv64-base
target-rv64-all
target-rv32-all
```

自定义：

```racket
(target 'rv64 '(rv_i rv_m rv_a rv_c rv64_i rv64_m rv64_a))
```

不做自动扩展闭包；`rv32_*` / `rv64_*` 不混用。

## 使用

target 是显式参数，没有全局 `current-target`：

```racket
(layout-program target program data layout-input)
(relax target program data layout-input)
(encode-layout target bound-layout)
(encode-instruction target name operands)
(integer->bytes width value)
(padding-bytes target kind n)
(run-flow target selector seeds)
```

`bind-labels` 不需要 target。

## 填充

`padding-bytes` 由 target 的扩展集推导：

- code 4 字节：`nop`
- code 2 字节：有 C 扩展时用 `c.nop`
- data：0
- 奇数余数：报错

## 不放进 target

操作数语法、段/place、ABI/栈/scratch、reloc/loader。
