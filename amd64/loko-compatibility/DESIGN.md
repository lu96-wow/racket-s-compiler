# loko-compatibility（stage: loko-compat）

> 目录：`loko-compatibility/`；flow 里的 stage 名仍是 `loko-compat`。

> 做写法兼容和前端元数据采集。输入和输出都是 s-expression；没有布局、
> 地址、编码，也没有跨调用状态。目标是把 Loko `arch/amd64` 现在吐出的
> 汇编写法接到本后端。

## 1. 作用

把 Loko `arch/amd64` 的旧汇编写法纯变换成本后端的核心 item，并采集
sections/origin/mode/symbols/comms 等 `loko-ir` 元数据。

## 2. 相关 s-exp：输入

```scheme
(loko-source
  (text item ...)   ; Loko 的 text / 代码
  (data item ...))  ; Loko 的 data / 数据
```

分开 `text` / `data` 是有意的：`%section` / `%origin` / `%mode` / `%comm`
作为 `loko-ir` 元数据采集；`%call` 和最终镜像布局仍属于 image 层。

`translate-loko-text-only` / `translate-loko-data-only` 是单边便利入口；如果代码引用了
另一边的 `%equiv`，用 `translate-loko-source`。

## 3. 相关 s-exp：输出

```scheme
(loko-compat
  (program-items item ...)
  (data-items item ...)
  (aliases (alias 名字 值) ...)
  (symbols (symbol start end section misc) ...)
  (comms (comm name size align) ...)
  (image-plan (entry ...) (region ...) (load ...) (symbol ...))
  (origin 地址|#f)
  (sections
    (section (name 名字) (kind code|data|hole)
             (modes (item下标 mode) ...)
             (items item ...))
    ...)
  (problems problem ...))
```

- `program-items` / `data-items` 已经是本后端的核心 item。
- `aliases` 是 `%equiv` 解析后的常量/地址表达式，供 image 层或调试使用。
- `symbols` 保留 Loko `%label` 的符号元数据：start/end 路径、section、misc。
- `comms` 保留 `%comm` 的原始声明；`translate.rkt` 已把它展开到 bss section。
- `sections` 的 `kind` 用后端词汇：源码的 `%section bss` 出 IR 时翻成 `hole`。
  “bss” 这个词只留在源码指令、section 名字和 ELF 段名里。
- `image-plan` 是 `%elf` 的显式声明，交给 `amd64-elf` 消费；不是过程。
  `region` 的 `content` 决定 PROGBITS/NOBITS，`perm` 决定 section/PT_LOAD 权限。
- `program-items` / `data-items` 是按 section kind 从 `sections` 重新推导的扁平视图。
- `origin` 是 `%origin` 设置的起址；`sections` 是按源顺序排列的 section run，
  `modes` 记录 mode 切换点的 item 下标。
- `problems` 是明确的问题列表；`loko-compatibility/flow.rkt` 在非空时报错。

## 4. 映射

| Loko 写法 | 核心写法 | 说明 |
| --- | --- | --- |
| `(mem64+ ...)` / `(mem32+ ...)` / `(mem+ ...)` | `(b64 ...)` / `(b32 ...)` / `(bN ...)` | `mem+` 从兄弟寄存器或基址推断宽度 |
| `(mem128+ ...)` | `(b128 ...)` | 用于 `movdqa` 等 SSE 内存操作数 |
| `(%label x)` | `(label x)` + `(symbol (x) (x) section ())` | symbol/string/number 保留原名；vector 等映射为 `loko-label-N` |
| `(%label a b . misc)` | `(label a)` + `(symbol (a) (b) section misc)` | `b` 是符号的 end label，不是同地址别名；`b` 由自己的 `%label` 定义 |
| `(%section name)` | `sections` 里的 section run | text/data/bss/elf；按源顺序保留 |
| `(%origin n)` | `(origin n)` | 整体起址；后续 image 层负责段布局 |
| `(%mode n)` | `(modes (item下标 n) ...)` | 16/32/64；同一 section 可多次切换 |
| `(%comm name size align)` | `(comm name size align)` + bss 段里的 `(align) (label) (reserve)` | 按 size 升序展开到第一个 bss section 开头 |
| `(%init-bss)` | 64 位：`cld` + `li` + `sub` + `xor` + `rep stosb` | 显式源码 marker；默认 `bss`/`bss-end`，clobber `rax rcx rdi` |
| `(%elf-header)` | 无（丢掉） | dump 标出的镜像头：ELF header + program headers，由 `amd64-elf` 重新生成 |
| `(%elf-tail)` | 无（丢掉，并截断其后所有 item） | dump 标出的 ELF 尾：segments/symtab/strtab/shstrtab + 汇编期 `%call` 钩子 |
| `(%call proc …)` | 无 | 汇编期闭包，不可序列化；正常输入里已被上面两个标记取代，残留则报 `directive-needs-image-layer` |
| `(%init-bss start end)` | 同上 | 自定义 BSS 起止 label |
| `(%elf (entry ...) (region ...) (load ...) (symbol ...))` | `image-plan` | `region` 是 canonical 身份；`content`/`perm` 派生 ELF 元数据 |
| `(%comment ...)` | `(comment ...)` | 零尺寸注记 |
| `(%align n)` / `(%align n 0)` | `(align n)` | 显式非零填充字节暂不支持 |
| `(%u8 v)` / `(%u16 v)` / `(%u32 v)` / `(%u64 v)` | `(value 1/2/4/8 v)` | 一条可展开成多条 |
| `(%u128 n)` | 两条 `(value 8 ...)` | 只支持整数；符号 128 位表达式显式报问题 |
| `(%vu8 bv)` | `(bytes ...)` | 字节原样 |
| `(%utf8z s)` | `(bytes ... 0)` | UTF-8 + NUL |
| `(%equiv name expr)` | `(alias name expr)` | 定义先收集，引用处内联 |
| `sal` | `shl` | 同一编码 |
| `movsxd` | `movsx` | 32 → 64 符号扩展 |
| `sete` / `setc` / `setnp` … | `(setcc cc rm)` | 条件码别名 |
| `cmovnc` / `cmovz` … | `(cmovcc cc dst src)` | 条件码别名 |
| `lock.xadd` / `rep.movs` … | `(prefix lock (xadd …))` / `(prefix rep (movs …))` | 前缀变成显式 form |
| `(call (mem...))` | `(call-indirect mem)` | 直接调用留给 expand-pseudo |
| `(jmp (mem...))` | `(jmp-indirect mem)` | 直接跳转留给 expand-pseudo |

## 4.1 `%init-bss`

源码形式：

```scheme
(%init-bss)             ; 默认 start=bss, end=bss-end
(%init-bss start end)   ; 自定义起止 label
```

它是显式 opt-in：源码里不写，就不会生成 BSS 清零代码。适用于 loader 不保证
清零 BSS 的镜像；普通 Linux ELF / Multiboot 可以完全不用它。

当前只展开 64 位：

```scheme
(cld)
(li rdi (bss))
(li rcx (bss-end))
(sub rcx rdi)
(xor eax eax)
(prefix rep (stos (b8 (base rdi) (disp 0)) al))
```

clobber：`rax`、`rcx`、`rdi`、flags。需要保留这些寄存器时，由源码自己
push/pop 或改用自定义指令序列。

限制：

- 必须出现在 `code` section；
- 必须已经设置 `%mode 64`；
- 起止 label 必须存在；`end >= start` 目前由源码/镜像布局保证；
- 32/16 位暂报 `init-bss-mode-unsupported`。

## 4.2 `%elf`

`%elf` 用 canonical region 模型描述 ELF：

```scheme
(%elf
  (entry text)

  (load (id text) (align 4096))
  (load (id data) (align 4096))
  (load (id bss)  (align 4096))

  (region (id text)
          (content materialized)
          (section .text)
          (perm r-x)
          (align 16)
          (load text))

  (region (id data)
          (content materialized)
          (section .data)
          (perm rw-)
          (align 8)
          (load data))

  (region (id bss)
          (content reserved)
          (section .bss)
          (perm rw-)
          (align 8)
          (load bss))

  (symbol (name elf-entry)
          (region text)
          (size 0)
          (type func)
          (bind global)))
```

规则：

- `content materialized` -> `SHT_PROGBITS`，必须有 build bytes；
- `content reserved` -> `SHT_NOBITS`，不能有 build bytes；
- `perm` 决定 section flags 和对应 load 的 `p_flags`；
- `region` id 是唯一身份；symbol 用 `region` 引用，不按 section 名字回退；
- `section` 只是显示名；
- `load` 只负责分组和 `p_align`，权限由成员 region 派生。

## 5. 边界：不在这里做的事

`%section` / `%origin` / `%mode` / `%comm` 已采集到 `loko-ir`，但还没有生成最终布局/镜像。
`%init-bss` 是显式 opt-in：源码不写就不生成清零代码；当前只展开 64 位，
32/16 位会报 `init-bss-mode-unsupported`。

`%comm` 已按 Loko 旧 assembler 的规则展开到 bss section。

以下写法仍反映 image/链接事实，当前显式报
`(problem directive-needs-image-layer ...)`：

```text
%call
```

本层不猜 BSS 位置、不调用宿主过程；`image/layout-spec.rkt` 和 `amd64-elf` 已经接上，`%call` 仍需声明式替代。

`$`（当前 IP）会原样变成核心地址表达式里的 `$`，由 layout / bind / encode
在求值时解析。带标签的 `bitwise-and` / `bitwise-ior` / `ash` /
`bitwise-bit-field` 也会保留到核心地址表达式；其它符号运算仍显式报
`symbolic-bit-expression`。

## 6. 设计思路：纯函数

- 输入列表不被修改。
- 标签表、别名表、section/origin/mode 状态、符号表、问题列表都是本次调用的局部数据。
- 输出只依赖输入；同样的输入得到同样的输出（匿名标签编号按遍历顺序固定）。
- 不 require `layout` / `encode` / `flow`，避免反向依赖。

## 7. 边界 / 测试

```sh
racket amd64/loko-compatibility/test.rkt
racket amd64/loko-compatibility/image/test.rkt
racket amd64/amd64-elf/test.rkt
```

## 8. 后续结构

`loko-compatibility/` 现在有语法适配器、第一版 image layout 和 lower：

```text
loko-compatibility/
  translate.rkt        ; 已有：旧写法 -> 核心 item + 符号元数据
  lower/               ; 已有：伪寄存器 / liveness / 图着色 / call save；见 lower/DESIGN.md
  image/layout-spec.rkt ; 已有：loko-ir -> layout-spec；见 image/DESIGN.md
  image/                ; 计划：%call

ELF writer 在 ../../amd64-elf/。
```

lower 目前还缺 spill 和 frame allocation；详细缺口见
[`../GAPS.md`](../GAPS.md)。

