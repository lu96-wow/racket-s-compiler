# riscv-compiler-rebuild-test

黑盒契约测试：只通过 `riscv-compiler-rebuild` 的公开 API 验证每一层的 s-exp
输入/输出、边界、问题交接，以及整条 `flow` 到字节的产物。

实现目录不动；这里只读它。

## 跑

```bash
racket run.rkt                 # 跑全部，逐文件打印，最后汇总
racket sexp-test.rkt           # 也可以单跑某一层
...
racket integration-test.rkt
```

## 文件

| 文件 | 对应层 / 契约 |
| --- | --- |
| `helpers.rkt` | 读 layout / build / problem 的小工具，不含编译器逻辑 |
| `sexp-test.rkt` | `form?` `name?` `path?` `normalize-path` `address-expr?` `as-items` |
| `expand-data-test.rkt` | rich 数据 → `(value 宽度 值)` / `(bytes …)` / `(fill …)` / `(pad …)` |
| `flatten-test.rkt` | `module` + `provide`/`require` + `prefix-in`/`rename-in`/`rename-out` |
| `expand-pseudo-test.rkt` | 替换表、别名平级、偏移补 0、透传、自环保护 |
| `analyze-test.rkt` | 指令分类、切块、`succ`/`fallthrough`、`root?` |
| `dce-test.rkt` | 不可达块、转移到下一块、空块合并、重新编号 |
| `layout-test.rkt` | `item-size`/`item-kind`/`form-range`、放置、对齐、符号、problems |
| `relax-test.rkt` | 提升阶梯、区间边界、收敛、`scratch-hole` 交接 |
| `encode-test.rkt` | 指令字、端序、aq/rl、填充策略、`li`/`la`/远形式、断言 |
| `flow-test.rkt` | stage 表、依赖检查、可选层、`layout`/`relax` 平层 |
| `integration-test.rkt` | 规范例子逐字节、模块+数据、rich 数据、完整流松弛、错误 |

## 测试里刻意锁住的 s-exp 形状

```
expand-data : (label …) (bytes …) (fill n b) (pad n) (value w v) (align n)
flatten     : 输入的链 -> 完整链；module/provide/require 壳消失
expand-pseudo : 表里的伪指令 -> 真指令；不认识的 form 原样
analyze     : (program (block <头链列表> item...) ...)
              (program (flow (succ id...) (fallthrough id|#f) (root? bool)) ...)
layout      : ((segments (segment (name …) (kind …) (start …) (end …) (align …)
                                   (items (offset k item) ...) (size n)) ...)
               (symbols (symbol 链 段名 偏移 绝对地址) ...)
               (problems ...))
build       : (build (segment (name …) (kind …) (start …) (size …) (bytes #vu8…)) ...)
```

`layout` / `relax` 的 problems 是交接点：`needs-far` 给 relax，`scratch-hole`
给尚未实现的寄存器使用层；`encode` 只要看到任何 problem 就拒绝出产物。

## 写测试时抓到的三个实现问题（已修）

新测试按 `DESIGN.md` 的契约写，第一次跑暴露了三个实现与契约不符的点；
下面三条现在是回归用例，实现也同步修正：

| 位置 | 现象 | 修正 |
| --- | --- | --- |
| `analyze/analyze.rkt` | `(jal x0 L)` 的目标正好是物理下一块时，`fallthrough` 被算成下一块（它并不会顺序落下） | `fallthrough` 用 `falls-through?` 判断，不再只看下一块是否在 `succ` 里 |
| `flatten/flatten.rkt` | `(prefix-in p: a)` 导入 `(d table)` 时只绑成 `(p:d)`，丢了 `table` | 前缀只加在链的头一节，保留尾巴 |
| `encode/encode.rkt` | `(jump-far ra L)` 的 link 非零，却因为“少一项”被当成 scratch 空槽拒绝 | 空槽 = 少一项 **且** link 是零寄存器 |
