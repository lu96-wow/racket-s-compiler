# riscv-compiler-rebuild

从 s-expression 汇编一路走到字节的编译器。**每层都是纯函数，可单独跑。**

```
      rich 数据 ─→ D1 数据定义 ─┐
                                │
source(多输入)                  ↓
program list ┐
data    list ├─ L1 展平 ─→ L2 替换 ─→ L3 分析 ─→ L4 死代码消除 ─→ L5 布局 ─→ L6 松弛 ─→ L7 编码
layout  list ┘                      program       program         (layout)     (layout)     (bytes)
```

## 先看这里

| 文档 | 内容 |
| --- | --- |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | **索引 + 规范**：分层地图、词汇边界、跨层铁律、IO 形状、形式归属、缺口清单、文档规范 |
| `D1/DESIGN.md` … `L7/DESIGN.md` | 每层自己的职责 / 输入输出 / API / 规则 / 边界 / 测试 / 缺口 |

外部依赖（同仓库的兄弟目录）：

| 包 | 管什么 |
| --- | --- |
| `../riscv-asm` | 指令编码表（操作数 → 指令字），含全部位域检查 |
| `../riscv-help` | `li` / `la` / 远分支 / 远跳转的展开器与判据 |

## 跑一遍

```bash
racket D1/test.rkt      # 每层都能单独测
...
racket L7/test.rkt

racket L7/demo.rkt      # 看最后一层：layout -> 字节（带 hexdump）
```

每层还有一个 `demo.rkt`，只出现**该层自己的**输入输出。
