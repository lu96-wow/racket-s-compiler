# encode（`insn.rkt` `encode.rkt` `syntax/*`）

## 作用

把 bound-layout 变成每个段一坨字节。负责端序、填充、`li` / `la` / 远形式展开，
以及把指令交给 `riscv-asm` 编码。

## 相关 s-exp

输入 bound-layout：

```racket
((phase bound)
 (segments (segment (name …) (kind …) (start …) (size …)
                    (items (offset k item) …)) …)
 (anchors …)
 (symbols (symbol 链 段名 偏移 绝对地址) …)
 (requests …)
 (problems …))
```

输出：

```racket
(build (segment (name …) (kind …) (start …) (size …) (bytes #vu8…)) …)
```

本层处理的 item：`label` / `pad` / `bytes` / `fill` / `value` / `reserve` / 真指令 /
`li` / `la` / `branch-far` / `branch-indirect` / `jump-far`。

## 设计思路

- 端序、填充策略、指令编码都属于“变二进制”，集中在这里。
- `(offset k item)` 是断言：实际写出的字节数必须正好到达 `k`。
- 有 request/problem 或 `phase` 不是 `bound` 就拒绝出产物。
- 操作数顺序由 `syntax/order` 的表处理，因为 `riscv-opcodes` 的声明顺序不是汇编写法。
- `li` / `la` / 远形式先由 `riscv-help` 展开成真指令，再逐条编码。

## 两种段，两条路径

本层只分两种：材料化的（`code` / `data`）逐条落字节；`hole` 只推进位置。
“洞从哪儿开始”不作为状态存在，它由段声明，不需要两个游标。

`hole` 段（kind = `hole`）：

- items 只可能是 `label` / `reserve`（`align` 已被 layout 归一化成 `reserve`）；
- 产出 `(segment … (size n) (bytes #""))`：**`size` 保留，字节为空**；
- 本层**不解释洞的内容**（加载器 / 程序 / 硬件决定），只做防御性断言：
  items 全部是位置类、`offset` 连续、`size` 等于 `reserve` 之和；
- 出现 `pad` / `bytes` / 指令等要写字节的 item 就报错：
  说明 layout 和 encode 对“这段是不是洞”的理解不一致。

## 边界

不选指令、不布局、不松弛、不绑地址、不填 scratch、不做加载器格式。
