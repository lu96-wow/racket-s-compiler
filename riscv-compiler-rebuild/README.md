# riscv-compiler-rebuild

从 s-expression 汇编一路走到字节的编译器。**每层都是纯函数，可单独跑。**

```
      rich 数据 ─→ expand-data ─┐
                                │
source(多输入)                  │  每层都是纯函数, 可单独测
──────────────                  ↓
program list ┐
data    list ├─ flatten ─→ expand-pseudo ─→ analyze ─→ dce ─→ relax ─→ encode
layout  list ┘                items          program    program  layout   bytes
```

`flatten` 是模块系统（`module` + `provide`/`require` + `prefix-in`/`rename-in`/`rename-out`，默认私有）。

层名就是目录名。**跑哪些层、什么顺序，由 `flow` 的一个列表决定**：

```racket
(run-flow '(expand-data flatten expand-pseudo analyze dce relax encode) seeds)
```

不写进列表的层就是关掉；`layout` 和 `relax` 是平层（同进同出），写 `relax` 就够了。

## 先看这里

| 文档 | 内容 |
| --- | --- |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | **索引 + 规范**：分层地图、词汇边界、跨层铁律、IO 形状、形式归属、缺口清单、文档规范 |
| `flow/DESIGN.md` | **构建流**：`(list 层名 ...)`、依赖检查、可选/顺序/平层 |
| `expand-data/DESIGN.md` … `encode/DESIGN.md` | 每层自己的职责 / 输入输出 / API / 规则 / 边界 / 测试 / 缺口 |

顶层还有两个"不属于任何层"的共享模块：`sexp.rkt`（s-exp 形状工具）和 `target.rkt`（XLEN / 端序 / 扩展集）。

外部依赖（同仓库的兄弟目录）：

| 包 | 管什么 |
| --- | --- |
| `../riscv-asm` | 指令编码表（操作数 → 指令字），含全部位域检查 |
| `../riscv-help` | `li` / `la` / 远分支 / 远跳转的展开器与判据 |

## 跑一遍

```bash
racket flow/test.rkt        # 整条流
racket flow/demo.rkt        # 打印层表 + 跑一遍 + 关掉某一层对比

racket expand-data/test.rkt # 每层也都能单独测
...
racket encode/test.rkt

racket encode/demo.rkt      # 看最后一层：layout -> 字节（带 hexdump）
```

每层还有一个 `demo.rkt`，只出现**该层自己的**输入输出。
