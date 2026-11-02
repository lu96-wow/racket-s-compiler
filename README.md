# racket-s-compiler

用 Racket 写的汇编后端实验：把真实 Scheme 系统（Loko）的 assembler 输入接过来，
自己完成布局、编码、镜像。目前有两个目标：

| 目录 | 内容 |
| --- | --- |
| `amd64/` | x86-64 后端（编码器 + 布局 + ELF/平铺镜像 + Loko/ELF 前端层） |
| `riscv/` | RISC-V 后端（同一套分层形状的参照实现） |
| `riscv/riscv-compiler-rebuild/` | RISC-V 汇编器重构版：native 为 base，GAS 为可选层 |

Loko 的源码树**不在这个仓库里**，在 `~/work/loko`（和本仓库并列）——它是上游
项目，有自己的构建系统和 ~2 GB 产物，我们只加了一个 dump target。位置、我们改
了什么、怎么重建，都记在
[`amd64/loko-compatibility/LOKO-TREE.md`](amd64/loko-compatibility/LOKO-TREE.md)。

跨层规则见 [`amd64/ARCHITECTURE.md`](amd64/ARCHITECTURE.md)；工具链
（dump → 流水线 → 镜像）见 [`amd64/tools/README.md`](amd64/tools/README.md)。

## 快速开始

```sh
# 1. 装/重建带 sexp target 的 Loko（自举两步，离线，依赖 ~/.akku）
amd64/tools/build-loko-target.sh            # 默认读 ~/work/loko

# 2. 用我们的后端编 Loko 自己的编译器（dump -> 流水线 -> ELF）
cd ~/work/loko && LOKO_PROGRAM_SEXP=/tmp/cl.sexp \
    env LOKO_SOURCE=.akku/lib .akku/env ./loko-prebuilt \
    -feval -ftarget=sexp --compile compile-loko.sps --output /tmp/cl.bin
cd ~/work/racket-s-compiler/amd64
racket tools/loko-flow.rkt /tmp/cl.sexp /tmp/clcache elf
racket tools/write-cached-elf.rkt /tmp/clcache/loko-elf.rktd /tmp/compile-loko

# 3. 裸机 REPL 镜像（dump + 流水线 + 平铺 + 装盘；-b 顺便启动验证）
amd64/tools/build-pc-image.sh -b

# 4. 测试
cd amd64 && ./run-tests.sh
```
