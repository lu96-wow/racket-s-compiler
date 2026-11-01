# amd64-asm

## 作用

amd64 的二进制编码层：寄存器事实、target 事实、单条真实指令的尺寸和字节。

## 目录

```text
amd64-asm/
  sexp.rkt        共享 s-exp 形状 + 内存操作数
  registers.rkt   寄存器 class / 编码事实
  target.rkt      目标事实 + 填充
  insn-core.rkt   共享 ModR/M + SIB + REX + 立即数范围
  insn.rkt        手写特殊 form + instruction-size + encode-instruction
  insn-generic.rkt  NASM 生成表：约束/选 form -> plan -> 字节生成
  nasm/           NASM insns.dat 原始/预处理快照
  binary-build/   解析、过滤、生成 NASM 指令表
  generated/      生成的 Racket 指令数据
  test.rkt        指令编码 golden test
  test-generated.rkt 生成表 golden test
  test-oracle.rkt LLVM MC 独立编码 oracle
```

## 文档

- [`INSTRUCTIONS.md`](INSTRUCTIONS.md)：指令类别、前缀、字符串指令
- [`DESIGN.md`](DESIGN.md)：x86 编码逻辑、约束归属、plan/encode 分层目标
- [`NASM.md`](NASM.md)：NASM 数据来源、生成流水线和扩展方式
- [`REGISTERS.md`](REGISTERS.md)：寄存器 class 与 REX/high-byte 事实
- [`TARGET.md`](TARGET.md)：target 与填充策略

## 使用

```racket
(require "amd64-asm/insn.rkt")
(instruction-size 'mov '(rax rbx))
(encode-instruction 'mov '(rax rbx))
```

## 不负责

- 布局 / 地址绑定 / 分支松弛
- Loko 旧写法
- 段 / ELF / reloc / loader

## 生成指令表

```sh
cd amd64/amd64-asm
make build          # 从 nasm/insns.pre.dat 生成 generated/gen/insn/nasm.rkt
make test
```

## 测试

```sh
racket amd64/amd64-asm/test.rkt
racket amd64/amd64-asm/test-generated.rkt
racket amd64/amd64-asm/test-oracle.rkt
```
