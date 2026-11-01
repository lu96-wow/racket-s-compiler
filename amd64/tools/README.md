# tools

这些工具只为**验证**：把真实 Loko 的 assembler 输出接到本后端，并避免每次
重跑 15 分钟的编译流水线。

## 1. 导出 Loko 程序

在 Loko 仓库应用 dump 补丁，然后重新构建 `loko`：

```sh
cd /path/to/loko
git apply /path/to/amd64/tools/loko-dump.patch
make -B loko
```

补丁使用 `(loko runtime init)` 的 `get-environment-variable` 和 R6RS
`write`，不依赖外部 SRFI-98 / `io-printer` 库。

编译目标程序：

```sh
LOKO_DUMP_PROGRAM=/tmp/prog.sexp \
  ./loko -ftarget=linux --compile program.sps --output /tmp/prog.bin
```

补丁会：

- 在 `generate-assembler` 之后导出 `pass-optimize` 的 text/data
  （`LOKO_DUMP_OPT`）；
- 在 `assembler-library` 之后导出完整 assembler 输入
  （`LOKO_DUMP_PROGRAM`），并去掉 ELF header/footer 的 `%call`；
- 把 label vector 按对象身份换成唯一符号，避免 `equal?` 合并同名 label。

## 2. 转成 Racket 可读形式

```sh
python3 tools/loko-portableize.py /tmp/prog.sexp
```

输出的 `/tmp/prog.sexp.p` 处理了：

```text
#{gensym |unique|}      -> loko-gensym-N
#vu8(1 2 3)             -> #"\x01\x02\x03"
#<rtd name>             -> loko-rtd-name
#\alarm / #\esc / ...   -> #\u...
#\xNN                   -> #\uNN
"\xNN;"                 -> "\xNN"
```

`\xHEX;` 的 `;` 是 Loko 的转义终止符；Racket 的 `\x` 只吃两个十六进制位，
所以必须去掉它，否则字符串会多一个 `;`。

## 3. 缓存布局

```sh
# loko-near: 全 near 分支，不跑 relax，只 layout 一次（约 6 分钟）
AMD64_FLOW_TIMING=1 racket tools/cache-loko-layout.rkt \
  /tmp/prog.sexp.p /tmp/prog.cache loko-near

# loko: short 起步 + relax（约 15 分钟，发布路径用）
racket tools/cache-loko-layout.rkt /tmp/prog.sexp.p /tmp/prog.cache loko
```

缓存的是 `bound-layout`，不是最终字节。之后改 encoder / ELF writer 只需：

```sh
racket tools/write-cached-elf.rkt /tmp/prog.cache /tmp/prog.elf
```

## 4. 已验证

使用 `tests/test-bugs.sps` 做过完整验证：

```sh
LOKO_DUMP_PROGRAM=/tmp/loko-tiny.sexp \
  ./loko -ftarget=linux --compile tests/test-bugs.sps --output /tmp/loko-tiny.bin

python3 tools/loko-portableize.py /tmp/loko-tiny.sexp
racket tools/cache-loko-layout.rkt /tmp/loko-tiny.sexp.p /tmp/loko-tiny-full.cache loko
racket tools/write-cached-elf.rkt /tmp/loko-tiny-full.cache /tmp/loko-tiny-full.elf
/tmp/loko-tiny-full.elf
# Tests passed
```

`loko-near` 和完整 `loko`（short+relax）两条路径都通过了运行验证。

### 布局改成"解由 layout 求解"之后（段声明只给 `size` / `align`）

重跑同一条链路（`loko`，18m24s）：

```sh
racket tools/cache-loko-layout.rkt /tmp/loko-tiny.sexp.p /tmp/loko-tiny-new.cache loko
racket tools/write-cached-elf.rkt /tmp/loko-tiny-new.cache /tmp/loko-tiny-new.elf
cmp /tmp/loko-tiny-full.elf /tmp/loko-tiny-new.elf && echo identical
/tmp/loko-tiny-new.elf
# identical
# Tests passed
```

**产物逐字节相同**：真实 Loko 程序的 section 尺寸恰好是页的整数倍，旧的
"紧凑打包"本来就落在页边界上；新规则把这些边界变成结构性的（由 plan 的
`(align 4096)` 兑现），而不是靠尺寸凑巧。

小程序的差别很大：没有 `%elf` 时后端会合成默认 plan，段很小、以前会挤在同一页，
内核把 `.bss` 的匿名页盖在 `.text` 上 → 入口 SIGSEGV。这条路径由
`tools/smoke-loko-elf.rkt` 守住（构建 + 真执行 + 每段独占一页）。

## 5. 注意

- `loko-near` 只用于正确性验证，不替代发布路径的 short+relax。
- dump/portableize 是 Loko 前端的外部工具，不属于 `compiler` 层。
