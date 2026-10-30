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

本层处理的 item：`label` / `pad` / `bytes` / `fill` / `value` / 真指令 /
`li` / `la` / `branch-far` / `branch-indirect` / `jump-far`。

## 设计思路

- 端序、填充策略、指令编码都属于“变二进制”，集中在这里。
- `(offset k item)` 是断言：实际写出的字节数必须正好到达 `k`。
- 有 request/problem 或 `phase` 不是 `bound` 就拒绝出产物。
- 操作数顺序由 `syntax/order` 的表处理，因为 `riscv-opcodes` 的声明顺序不是汇编写法。
- `li` / `la` / 远形式先由 `riscv-help` 展开成真指令，再逐条编码。

## 边界

不选指令、不布局、不松弛、不绑地址、不填 scratch、不做加载器格式。
