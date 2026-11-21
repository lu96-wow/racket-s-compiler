# encode

`encode` 把 `layout-result` / `program-layout` 变成字节。第一版只做 32-bit native 指令。

```text
layout-result
  -> 计算 label offset
  -> 指令 + label 相对偏移
  -> riscv-asm 编码
  -> little-endian bytes

program-layout
  -> function-section：单独 encode
  -> raw-section：单独 encode（固定 4 字节）
  -> data-section：直接取 data bytes
  -> 按 base 补零字节
  -> 拼接 section bytes
  -> encoded-program
```

实现：[`encode.rkt`](encode.rkt)。测试：[`test/encode-test.rkt`](../test/encode-test.rkt)。

## 输入 / 输出

```racket
(require "encode/encode.rkt")

(encode-layout layout-result #:xlen 64)
;; => (encoded bytes labels)

(encode-program program-layout #:xlen 64)
;; => (encoded-program bytes sections)
```

单函数：

- `encoded-bytes`：函数的字节串；
- `encoded-labels`：label -> 函数内偏移；
- `encoded-size`：字节数。

程序级：

- `encoded-program-bytes`：所有 section 拼接后的字节串；
- `encoded-program-relocations`：外部 relocation 列表；
- `encoded-program-sections`：每个 `encoded-section` 含 kind / name / base / size / local labels；
  kind 是 `code` / `raw` / `data`；
- `encoded-program-size`：总字节数。

## 规则

- `encode-layout` 只接受单函数 `layout-result`；
- `encode-program` 只接受 `program-layout`；
- 所有 flat item 都按 4 字节计；`call-target` 按 8 字节计但 `encode-layout` 拒绝；
- branch / jal 的 label 变成相对当前指令的偏移；
- `call-jal` 已经带相对偏移，直接编码成 `jal x1, delta`；
- program-layout 的远调用已经展开成 `auipc` + `jalr`；
- program-layout 的 `addr-global` 已经展开成 `auipc` + `addi`；
- 外部 call / addr / data 地址初值输出 relocation 记录；
- `asm-code` 作为封闭块递归编码，使用自己的局部 label 表；
- raw-section 的 label / 分支 / `jal` 按段内偏移编码；
- data-section 的字节按 little-endian 直接写出；
- section 之间按 base 补 0 字节；
- 操作数 `(native xN)` 转成 `xN` 交给 `riscv-asm`；
- 整数原样；
- `(global ...)` 需要 relocation，报错；
- 一条指令的编码尺寸必须等于 layout 假设的 4 字节；
- 输出 little-endian。

## 当前支持

layout-relax 产出的：

- `addi` / `add` / `sub` / `and` / `or` / `xor` / shift / `mul` 等；
- `lbu` / `lb` / `lhu` / `lh` / `lwu` / `lw` / `ld`；
- `sb` / `sh` / `sw` / `sd`；
- `lui` / `auipc`；
- `beq` / `bne` / `blt` / `bge` / `bltu` / `bgeu`；
- `jal` / `jalr`；
- `ebreak`。

## 暂不支持

- 单函数 `layout-result` 里的未解析 `call-target` / `addr-global`；
- 外部符号 relocation / linker；
- raw 内远跳 / island；
- 跨 raw / func 的跳转；
- 全局地址的 far 形式；
- RVC / 压缩指令；
- island 的跨函数地址。

## 依赖

指令编码复用：

```racket
../../riscv-compiler/encode/insn.rkt
../../riscv-compiler/target.rkt
```

它们只是 `riscv-asm` 的适配层；真正的编码表在 `riscv-asm`。
以后可以把这层适配移进 `riscv-core`，不影响本接口。
