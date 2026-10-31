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
  (segment (name ...) (kind code|data|hole)
           (start ...) (size ...) (bytes ...))
  ...)

(symbol chain segment offset address)
...

;; 可选，来自 loko-ir 的显式计划
(image-plan
  (entry ...)
  (load (id text) (align 4096))
  (region (id text)
          (content materialized)
          (section .text)
          (perm r-x)
          (align 16)
          (load text))
  (symbol (name (text)) (region text) (size ...) (type func) (bind global)))
```

`region` 是 canonical 身份：

- `content materialized` -> PROGBITS，要求 build bytes；
- `content reserved` -> NOBITS，要求 build bytes 为空；
- `perm` 同时派生 section flags 和 PT_LOAD flags；
- `load` 只分组和对齐，不单独设置权限。

输出：

```scheme
(elf
  (entry 地址)
  (size n)
  (sections (section ...) ...)
  (bytes #"..."))
```

## 3. 当前布局

- 没有 plan 时：一个 `PT_LOAD`，覆盖最小段起点到最大段终点的连续虚拟内存；
- 有 plan `load` 时：每个 build segment 一个 `PT_LOAD`，权限/对齐来自 plan；
- `kind hole` 的段是 `p_filesz < p_memsz` 的零填充区（`.bss` 就是一例）；
- 另加 `PT_GNU_STACK`；
- `.text` / `.data` / `.bss` / `.symtab` / `.strtab` / `.shstrtab` section headers；
- `kind hole` 的段写成 `SHT_NOBITS`（段名叫 `bss` 时 section 名就是 `.bss`）；
- 符号名做简单 mangle；plan 可以覆盖 `size` / `type` / `bind` / `section`；
- 入口优先 plan entry，其次 `elf-entry`，再回退第一个 code segment 起点。

## 4. 边界

- 不做 reloc / dynamic linking。
- 没有 plan 时默认单 `PT_LOAD` 且是 RWX；有 plan `load` 时可拆成 text/data/bss 独立段。
- 符号 `st_size` 默认 0；plan `symbol` 可以显式覆盖。
- `%call` 生成的 Loko ELF header 还没有被替换。
- `kind hole` 的段最好排在所有非 hole 段之后；夹在中间会让后面的字节按文件偏移错位。
- section 尺寸来自已编码的 `build`，不在本层重新布局。

## 5. 测试

```sh
racket amd64/amd64-elf/test.rkt
```
