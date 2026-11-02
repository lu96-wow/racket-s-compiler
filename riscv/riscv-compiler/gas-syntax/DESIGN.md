# gas-syntax（可选）

## 作用

把 GAS 风格的操作数顺序改写为 `riscv-opcodes` native 顺序：

```scheme
(sw t0 sp 8)             -> (sw 8 sp t0)
(beq a0 a1 (L))          -> (beq (L) a0 a1)
(csrrw a0 mstatus a1)    -> (csrrw a0 a1 mstatus)
(amoadd.d.aqrl a0 a2 a1) -> (amoadd.d.aqrl a0 a1 a2)
```

这一层是**纯表替换**：不编码、不布局、不绑地址、不判断指令是否合法。
默认流不包含它。

## 相关 s-exp

输入/输出都是 `program-items`：

```racket
(require "rewrite.rkt")
(gas-rewrite-program target program-items)
```

## 表

`order-table.rkt` 只声明：

```text
native 第 i 个操作数 = GAS 操作数的第几个位置
```

例如：

```racket
"simm12 rs1 rs2" -> '(2 1 0)
"bimm12 rs1 rs2" -> '(2 0 1)
"rd rs1 csr"     -> '(0 2 1)
```

`aq` / `rl` 不占表面操作数，只记录插入位置；表面继续用 `.aq` / `.rl` / `.aqrl`。

表里没有的形状不做猜测，原样透传，由 native 层报错。

## 边界

- 不改变 label、模块名、数据 item。
- 不把 native 程序再“翻译”一遍；只在显式选择 GAS 方言时运行。
- 不负责 `load-8` / `store-*` / `branch-le` 这类便利别名；那属于可选的
  `expand-pseudo`。
