# data：全局数据

`data` 是全局数据段，不进入 virtual IR / allocation / materialize。

```scheme
(data (d table)
  (align 8)
  (value 8 0)
  (value 8 42)
  (bytes 1 2 3 4)
  (fill 8 0))
```

`func` / `data` / `raw` 的名字都是全局链，受 module 的 `provide` / `require` 管理。
模块规则见 [`MODULES.md`](MODULES.md)。

## 1. 形状

```scheme
(data chain item ...)
```

- `chain` 是数据段入口的全局名。
- `item` 是下面的核心数据 item。
- 所有形状都是 proper list；不使用 dotted pair。

## 2. 核心 item

| item | 含义 | 尺寸 |
| --- | --- | --- |
| `(align n)` | 把当前段内偏移对齐到 `n`，补 0 字节 | 由游标决定 |
| `(label chain ...)` | 在当前段内偏移定义全局 label | 0 |
| `(bytes b ...)` | 依次写入字节，`b` 在 `0..255` | 元素个数 |
| `(fill n b)` | 写入 `n` 个字节 `b`，`b` 在 `0..255` | `n` |
| `(value w v)` | 写入 `w` 字节小端整数或地址，`w ∈ {1,2,4,8}` | `w` |

约束：

- `(align n)` 的 `n` 必须是正的 2 的幂。
- `(label chain ...)` 至少有一个链；这些链都是全局名，指向当前段内偏移。
  label 不占字节，也不能改变对齐。
- data label 的完整链是 `模块名 + chain`，和 raw label 同一规则；
  例如模块 `(m)` 里的 `(label (end))` 得到 `(m end)`。
- `(fill n b)` 的 `n` 是非负整数。
- `(value w v)` 的 `v` 是整数时，允许范围是补码能表示的范围：
  `[-2^(8w-1), 2^(8w) - 1]`，按低 `8w` 位写入。
- `(value w (global chain))` 写入地址；地址宽度 `w` 只能是 4 或 8。
- `(value w (+ (global chain) n))` 写入地址加整数偏移 `n`。
- 地址值是绝对地址：`program origin + 目标起始偏移 + addend`。
  第一版 `layout-program` 的 `#:origin` 默认 0。
- 地址目标必须在同一个 program 里；未定义目标报错。
- 地址值必须落在 `0 .. 2^(8w)-1`；超出报错。
- 字节序固定 little-endian。
- `(align n)` 补 0，不是 NOP。
- 第一版没有 `(reserve n)` / `(pad n)`。
- 地址初值只支持 `(global chain)` 和 `(+ (global chain) n)`，不支持减法 /
  两个符号相减。
- data label 可以出现在 `(global ...)` 地址初值、`addr(global ...)` 和
  `provide` / `require` 里。

## 3. 段大小与对齐

- `data` 的尺寸由 item 顺序累加得到。
- `(align n)` 按**段内偏移**对齐。
- program layout 把整个 data 段的起点对齐到该段内所有 `align` 的最大值；
  因此段内 `align` 也等于绝对地址对齐。
- 地址初值在 program layout 完成所有段放置后再回填。
- 没有 `align` 时段对齐为 1。
- program layout 把函数放在前面，data 段按输入顺序放在后面。
- 段与段之间的对齐填充是 0 字节。

## 4. 地址：`addr(global chain)`

`addr` 是 virtual IR 里的显式地址操作：

```scheme
(addr ($ p) (global (d table)))
```

- 源可以是函数名或 data 名，只要在同一个 program 里。
- 第一版不支持 `(+ (global ...) n)`；需要偏移时用整数算术。
- materialize 之后仍然是 `(addr (native xN) (global chain))`。
- lower-ops 不展开全局地址。
- layout-relax 把它保留成 `(addr-global (native xN) (global chain))`，按 8 字节计。
- program-layout 根据目标地址和当前地址解析成：
  ```scheme
  (auipc (native xN) hi)
  (addi  (native xN) (native xN) lo)
  ```
- 如果 PC-relative delta 放不进 `auipc+addi`，使用绝对地址 `lui + addi`
  （仍然是 8 字节）；绝对地址必须能由 `lui+addi` 表示，否则显式报错。
- 第一版没有带 scratch 的任意 64-bit 绝对地址序列。
- 未定义目标显式报错。

`addr` 的结果是一个指针值，可以参与普通整数运算；没有隐式 local load/store。

## 5. 与 module / raw 的关系

- data 名是全局名，参与 `provide` / `require` / `rename-in` / `rename-out`。
- data 内部 label 是全局名，参与 `provide` / `require` / rename / prefix。
- `raw` 已经接入 program layout（顺序：函数 → raw → data）；
  raw 与 data 的**统一 section 模型**还没有实现。
- 跨模块变量是 `data` + `addr` / `load` / `store`，不是 vreg。

## 6. 实现位置

| 文件 | 作用 |
| --- | --- |
| `data/data.rkt` | data 形状、item 校验、label 偏移、尺寸、字节、地址 relocation |
| `layout/relax.rkt` | `addr(global)` -> `(addr-global ...)`，按 8 字节保留 |
| `layout/program.rkt` | 函数/数据段偏移、data 段放置、`addr-global` 解析 |
| `encode/encode.rkt` | data 字节、段间 padding、程序级拼接 |

## 7. 暂不支持

- `(reserve n)` / hole 段；
- 地址减法 / 符号相减；
- 地址宽度 1 / 2；
- data label 的 nested chain / 子段；
- raw 与 data 的统一布局；
- 带 scratch 的任意 64-bit 全局地址；
- 外部符号 / relocation / linker；
- RVC。
