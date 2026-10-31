# amd64-elf

> 目录：`amd64/amd64-elf/`
>
> 通用 amd64 ELF64 writer。输入是 compiler 的 `build` 和 symbols，
> 不依赖 Loko 前端。

## 1. 模块

```text
writer.rkt   build + symbols -> ELF64 image
test.rkt     header / program header / section / symtab 检查
```

## 2. 输入输出

输入：

```scheme
(build
  (segment (name ...) (kind code|data|bss)
           (start ...) (size ...) (bytes ...))
  ...)

(symbol chain segment offset address)
...
```

输出：

```scheme
(elf
  (entry 地址)
  (size n)
  (sections (section ...) ...)
  (bytes #"..."))
```

## 3. 当前布局

- 一个 `PT_LOAD`，覆盖最小段起点到最大段终点的连续虚拟内存；
- 末尾的 bss 是 `p_filesz < p_memsz` 的零填充区；
- 另加 `PT_GNU_STACK`；
- `.text` / `.data` / `.bss` / `.symtab` / `.strtab` / `.shstrtab` section headers；
- `.bss` 使用 `SHT_NOBITS`；
- 符号名做简单 mangle；
- 入口默认找 `elf-entry`，没有则回退第一个 code segment 起点。

## 4. 边界

- 不做 reloc / dynamic linking。
- 单 `PT_LOAD` 当前是 RWX；后续应拆成 text/data 独立段。
- 符号 `st_size` 目前为 0。
- `%call` 生成的 Loko ELF header 还没有被替换。
- bss 最好位于所有非 bss 段之后；中间 bss 会被写成文件零字节。
- section 尺寸来自已编码的 `build`，不在本层重新布局。

## 5. 测试

```sh
racket amd64/amd64-elf/test.rkt
```
