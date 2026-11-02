# Loko 源码在哪

**`~/work/loko`** —— 仓库外面，和 `racket-s-compiler/` 并列。

```text
~/work/
├── loko/                  Loko Scheme 源码树 + 我们加的 sexp / sexp-pc target
└── racket-s-compiler/     这个仓库（amd64 + riscv 两个后端）
```

工具默认就读这个路径（`amd64/tools/build-loko-target.sh`、
`amd64/tools/build-pc-image.sh`）；换位置用 `LOKO=/path/to/loko` 或脚本的第一个
位置参数覆盖。

## 为什么在仓库外面

Loko 是上游项目（0.13.1-dev），有自己的 GNUmakefile、akku 依赖和 ~2 GB 的构建
产物（`.akku/` 1 GB、`bin/pc-repl/*.img` 各 489 MB）。它只在**验证**时被用到：
用它的前端把程序编成 assembler 输入，后端是我们自己的。为了让仓库保持"可读、
可 clone"，源码树留在外面，仓库里只记录**它是什么、改了什么、怎么重建**。

上游 git 历史不在树里：搬家时把 `.git` 挪到了 `~/tmp-artifacts/loko-git`
（要跟上游同步、看 diff 时用它）。

## 我们对 Loko 的三处改动

| 文件 | 改动 |
| --- | --- |
| `arch/amd64/sexp-asm.sls` | 新文件：`sexp` / `sexp-pc` 两个 **dump target**（用 `(loko arch asm) register-target` 注册）。不发射 ELF、不产字节，把 assembler 输入直接写成 Racket 能读的 s-expression |
| `compile-loko.sps` | +2 行（import + `sexp-asm:visit`），否则自举出来的编译器不认识这两个 target |
| `compiler/static.sls` | 静态库列表 +1 行；`get-scheme-libraries` 加 `[(sexp) '(linux)]` |

最后一行是踩过的坑：`get-scheme-libraries` 按 `target-kernel` 决定静态链接哪些
运行库。`-ftarget=sexp` 不映射成 `linux` 的话 `kernels` 是空表，
`linux-start` / `linux-init` / `linux-syscalls` / `elf-start` 都不进程序 ——
镜像能链接、能运行，但启动就对着小整数解引用（实测 SIGBUS，`rax=0x2f`）。

## 重建

```sh
amd64/tools/build-loko-target.sh          # 检查 4 处安装面 + 重建 .akku/lib/loko + 自举两步
```

自举走 `./loko -feval --compile compile-loko.sps` → `./compile-loko` → 运行它，
**不要** `make loko-prebuilt`（Chez 路径，需要 akku 的 `.loko.sls` 布局，还会被
`runtime/parameters.chezscheme.sls` 抢先加载）。

`.akku/lib/loko` 是 akku 的构建目录（工作树副本 + 系统安装里的生成文件），
脚本会重建它。**不要**手工 `rm -rf .akku/lib/loko` 之后跑 `make -B` /
`akku install`：akku 会把 `.akku/lib/loko`（`LOKO_SOURCE` 指向的自有库目录）
换成它自己的副本，打进补丁的 `compiler/main.sls` 就丢了。

`config.sls` 是 `config.sls.in` 生成的（`make config.sls`），不是源码；
它必须是树内的普通文件 —— 曾经它是个指向 `../../../config.sls` 的符号链接，
内容落在 `~/config.sls`（仓库/树外），搬家时已修掉。

## 用它的两种后端

```sh
cd ~/work/loko

# 1. Loko 自己的 linux 后端（对照用）
LOKO_SOURCE=.akku/lib .akku/env ./loko-prebuilt \
    -ftarget=linux --compile tests/test-bugs.sps --output /tmp/t.bin

# 2. 我们的 amd64 后端：dump 出 assembler 输入，剩下的交给 racket-s-compiler
LOKO_PROGRAM_SEXP=/tmp/prog.sexp LOKO_SOURCE=.akku/lib .akku/env ./loko-prebuilt \
    -feval -ftarget=sexp --compile tests/test-bugs.sps --output /tmp/prog.bin
cd ~/work/racket-s-compiler/amd64
racket tools/loko-flow.rkt /tmp/prog.sexp /tmp/cache elf
racket tools/write-cached-elf.rkt /tmp/cache/loko-elf.rktd /tmp/prog.elf
```

`sexp-pc` 是裸机那条（`bin/pc-repl/pc-repl.sps` → 平铺镜像 + multiboot），
见 [`../tools/README.md`](../tools/README.md) 第 6.1 节。
