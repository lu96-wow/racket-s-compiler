# racket-s-compiler

用 Racket 写的汇编后端实验：把真实 Scheme 系统（Loko）的 assembler 输入接过来，
自己完成布局、编码、镜像。目前有两个目标：

| 目录 | 内容 |
| --- | --- |
| `amd64/` | x86-64 后端（编码器 + 布局 + ELF/平铺镜像 + Loko/ELF 前端层） |
| `riscv/` | RISC-V 后端；`riscv-compiler` 只使用 riscv-opcodes native 顺序 |