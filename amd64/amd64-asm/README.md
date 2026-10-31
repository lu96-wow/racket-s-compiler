# amd64-asm

## 作用

amd64 的二进制编码层：寄存器事实、target 事实、单条真实指令的尺寸和字节。

## 目录

```text
amd64-asm/
  sexp.rkt        共享 s-exp 形状 + 内存操作数
  registers.rkt   寄存器 class / 编码事实
  target.rkt      目标事实 + 填充
  insn.rkt        指令表 + instruction-size + encode-instruction
  test.rkt        指令编码 golden test
```

## 文档

- [`INSTRUCTIONS.md`](INSTRUCTIONS.md)：指令类别、前缀、字符串指令
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

## 测试

```sh
racket amd64/amd64-asm/test.rkt
```
