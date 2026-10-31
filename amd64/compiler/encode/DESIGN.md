# amd64 encode

## 作用

把 `bind-labels` 之后的 `bound-layout` 变成每段的最终字节。

```racket
(encode-layout target bound-layout) ; -> build
```

只处理“已经有绝对地址、尺寸已经固定”的产物；不选择形式、不松弛、不布局。

## 相关 s-exp

| 输入 | 输出 |
| --- | --- |
| `((phase bound) (segments …) (symbols …) (requests …) (problems …))` | `(build (segment …) …)` |
| `(offset k item)` | 当前段从 offset k 开始的字节 |
| `(symbol 链 段名 偏移 绝对地址)` | 符号地址解析 |
| `(value 宽度 值)` | 按 target 端序落成宽度个字节 |
| `(reserve n)` | 只在 bss 段合法；由 bss 段整体跳过字节输出 |
| `item` 指令 | 操作数解析后交给 `insn.rkt` 编码 |

## 设计思路

- 只接受 `phase = bound` 的布局。
- requests / problems 非空就拒绝出产物。
- 每条 `(offset k item)` 是断言：实际写出的游标必须正好到 k。
- 段末尾再断言一次：实际字节数必须等于 layout 的 `size`。
- 符号内存 displacement、RIP-relative displacement、分支相对偏移都在本层解析。
- 指令字节由 `insn.rkt` 的同一套 `instruction-size` / `encode-instruction` 提供，
  不在 encode 层重新维护指令尺寸。
- `prefix` form 的内部操作数递归解析；内部 RIP-relative 以 `here + 1` 为基准。
- `kind bss` 段返回 `(bytes #"")`，`size` 保留内存大小；BSS 内容由 loader 清零。
- `reserve` 出现在非 bss 段时拒绝编码。

## 边界

- 不做指令选择、寄存器分配、分支松弛。
- 不改 item、不改 offset/size。
- 不生成 reloc / loader 信息。
- 不处理 far form / scratch 填充；有未解决 request 就拒绝。
