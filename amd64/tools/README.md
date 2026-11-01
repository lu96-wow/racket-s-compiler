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
  （`LOKO_DUMP_PROGRAM`）；
- 把 label vector 按对象身份换成唯一符号，避免 `equal?` 合并同名 label；
- 把汇编期 ELF writer 的两段产物换成**声明式标记**（见下）。

### ELF writer 的标记：`%elf-header` / `%elf-tail`

`%call` 是汇编期闭包（`(%call proc arg …)`，`proc` 拿到 `assemble!/ip/symbols/bss`
直接发 item 并返回位置增量），不可序列化。Loko 里它的三处用途**全部是 ELF
writer**：头回卷、strtab、symtab。所以 dump 只负责标出这两段：

| 标记 | 范围 | 谁负责 |
| --- | --- | --- |
| `(%elf-header)` | `#(elf start)` 到程序内容的第一条 | `amd64-elf` 重新生成 |
| `(%elf-tail)` | 第一个 `%call` / `%section elf` 之后全部 | `amd64-elf` 重新生成 |

`loko-compat` 丢掉它们（`strip-elf-wrapper`）：头部直接忽略，尾部之后没有任何
程序内容所以直接截断。于是 `%call` 不会出现在编译器输入里，而"哪些东西属于
镜像格式"这个判断留在编译器一侧，Loko 不打补丁也能说出形状。

裸的 `%call` 仍然报 `directive-needs-image-layer` —— 那说明输入还带着汇编期的
ELF writer，需要重新导出。

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

## 4.1 我们已经不需要这个补丁了：`sexp` target

`loko-target/` 里是 Loko 的一个 **target 插件**（用 Loko 公开的
`(loko arch asm) register-target` 接口）：它不发射 ELF 头/尾，也不产字节，
而是把 assembler 输入直接写成 Racket 能读的 s-expression。于是下面这些全都不需要：

| 不需要 | 原因 |
| --- | --- |
| `tools/loko-dump.patch` | 不再往 `compiler/main.sls` 里加 dump 钩子 |
| `tools/loko-portableize.py` | 我们自己的 printer 直接吐可读形式 |
| `%call` / `%elf-header` / `%elf-tail` | target 根本不发射 ELF writer 的内容 |

target 的源码在 **Loko 仓库里**（`arch/amd64/sexp-asm.sls`），本仓库不保留副本，
避免两处漂移。安装面共 4 处（一次性，都在 Loko 树里）：

```text
arch/amd64/sexp-asm.sls                    新文件（target 插件）
compile-loko.sps                           +2 行（import + sexp-asm:visit）
compiler/static.sls                        +1 行（静态库列表）
compiler/static.sls                        +1 行 get-scheme-libraries: [(sexp) '(linux)]
```

最后一行的作用：`get-scheme-libraries` 按 `target-kernel` 决定要静态链接哪些运行库。
`-ftarget=sexp` 如果不映射成 `linux`，`kernels` 就是空表，`loko/arch/amd64/linux-start`、
`linux-init`、`linux-syscalls`、`elf-start` 都不会进程序 —— 编出来的镜像能链接、能运行，
但初始化缺一大堆，启动就对着一堆小整数当指针解引用（实测 SIGBUS，`rax=0x2f`）。

**已验证**：`tests/test-bugs.sps` 用这条路编出来的镜像跑出 `Tests passed`
（3,763,416 B，与旧路径同尺寸）。

用 `tools/build-loko-target.sh` 装好并重建；之后：

```sh
LOKO_PROGRAM_SEXP=/tmp/prog.sexp ./loko-prebuilt -ftarget=sexp \
    --compile tests/test-bugs.sps --output /tmp/prog.bin
racket tools/cache-loko-layout.rkt /tmp/prog.sexp /tmp/prog.cache loko-near
```

注意：`.akku/lib/loko` 是 akku 的构建产物，脚本会用"工作树副本 + 系统安装里的
生成文件"重建它；**不要**手工 `rm -rf` 它之后跑 `make -B`（那会把工作树里的库
文件换成悬空符号链接，见下一节）。

## 5. 在 QEMU 里跑产物（整机，不是用户态）

```sh
./tools/qemu-run.sh /tmp/prog.elf [程序参数…]
```

脚本把 ELF 当作 `/prog` 塞进一个最小 initramfs（busybox + 它的动态库），用宿主机
`/boot/vmlinuz-$(uname -r)` 当 `-kernel` 启动，`/init` 跑程序并打印退出码，脚本
把该退出码当自己的退出码。跑一次约 2 秒。

这条路验证的是**真实内核装载**：`PT_LOAD` 的地址/权限、段是否重叠、入口是否可执行、
内核 ABI。用户态直接执行（内核 execve 同一份 ELF）查不出“内核把某段放到别处”这类
问题；QEMU 里 boot 一遍就能查出。

```sh
./tools/qemu-run.sh /tmp/prog2.elf
# Tests passed
# exit 0

QEMU_ACCEL=tcg ./tools/qemu-run.sh /tmp/prog2.elf
# Fatal: Loko can't run because the system does not support #AC.
# exit 70
```

### 两个坑（都不是本后端的问题，但必须知道）

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `Fatal: Loko can't run because the system does not support #AC.`（exit 70） | Loko 启动时验证 #AC 真能触发 SIGBUS（`arch/amd64/linux-init.sls` 的 `linux-init-check-alignment`，靠一次未对齐读）。QEMU 的 **TCG 不实现 AC 标志**，未对齐访问不陷入，于是走到 valgrind 探测分支直接 `exit 70` | 用 `-accel kvm`（默认）；`-cpu host` 也只支持 KVM/HVF，TCG 用 `-cpu max` |
| `mmap` `errno: 12` ENOMEM，`&irritants: (#x10020000000 1 GiB 3 50 -1 0)` | Loko 启动就 `mmap` 1 GiB 堆（`MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS`），内核按 overcommit 记账；guest 内存 1 GB 时装不下 | `QEMU_MEM=2048`（默认）或更大 |

### 怎么判断自己的环境支持不支持 #AC

`tools/acprobe.s` 是 12 行汇编：打开 AC 后做一次未对齐读。支持 #AC 就被 SIGBUS 打死
（exit 135），不支持就正常 exit 0。不依赖 Loko，可以拿来量任何环境：

```sh
as -o /tmp/acprobe.o tools/acprobe.s && ld -o /tmp/acprobe /tmp/acprobe.o
/tmp/acprobe; echo "exit=$?"                 # 本机 CPU（含虚拟机里的 vCPU）
./tools/qemu-run.sh /tmp/acprobe            # QEMU/KVM
QEMU_ACCEL=tcg ./tools/qemu-run.sh /tmp/acprobe
```

实测（本机＝虚拟机，宿主暴露了嵌套虚拟化）：

| 环境 | acprobe | Loko 镜像 |
| --- | --- | --- |
| 直接执行（vCPU） | exit 135，SIGBUS | 能跑 |
| QEMU + KVM | exit 135，SIGBUS | 能跑 |
| QEMU + TCG | exit 0，**没有 #AC** | 全部 exit 70（原生后端也一样） |

所以在虚拟机里不需要 QEMU 也能验证产物：直接 `./prog.elf` 就行，vCPU 是真实 CPU 行为。
QEMU 只是额外补一道“真内核开机”的检查，没 KVM 时不要指望 TCG 能跑 Loko 镜像。

### 已验证

| 镜像 | 大小 | 用户态执行 | QEMU/KVM |
| --- | --- | --- | --- |
| `tests/test-bugs.sps`（本后端） | 3,763,416 B | `Tests passed` | `Tests passed` |
| `tests/test-bugs.sps`（Loko 原生 `-ftarget=linux`） | 1,714,147 B | `Tests passed` | `Tests passed` |
| `tests/test-bounded-control.sps`（本后端） | 3,785,592 B | 13 项全 OK，exit 0 | 同样输出，exit 0 |

`run-tests.sh` 里也挂了这条冒烟，但只在显式指定镜像时才跑：

```sh
QEMU_SMOKE_ELF=/tmp/prog.elf ./run-tests.sh
```

## 5.1 裸机（pc / multiboot）镜像

同一个后端也能产 Loko 的**裸机**镜像。一条命令：

```sh
# 默认读 ~/work/tmp/loko，产出 /tmp/pc-flat.bin 和装好的磁盘副本
./tools/build-pc-image.sh            # 只构建
./tools/build-pc-image.sh -b         # 构建 + 启动 QEMU/KVM，检查 REPL 画出来了
```

脚本从零跑一遍约 6 分钟（第二次起流水线全命中缓存，约 1 分钟）。下面是分步
说明，每一步都能单独跑。

链路和 Linux 那条平行：

```sh
# 1. Loko 侧 dump（sexp-pc target 在 Loko 仓库 arch/amd64/sexp-asm.sls）
cd ~/work/tmp/loko/bin/pc-repl
LOKO_PROGRAM_SEXP=/tmp/pc.sexp .akku/env ../../loko-prebuilt \
    -feval -ftarget=sexp-pc --compile pc-repl.sps --output /tmp/pc.bin

# 2. 我们的流水线（逐层缓存；这个镜像 1.6M 个 item，不缓存要重跑很久）
cd ~/work/racket-s-compiler/amd64
racket tools/loko-flow.rkt /tmp/pc.sexp /tmp/pcflow loko-near

# 3. 平铺镜像（没有 ELF 头，multiboot 加载的是一坨连续字节）
racket tools/write-flat-image.rkt /tmp/pcflow/encode.rktd /tmp/pc-flat.bin

# 4. 塞进磁盘镜像的副本并启动（mtools 改 FAT 分区里的 boot/loko）
cp ~/work/tmp/loko/bin/pc-repl/loko-hdd.img /tmp/test-hdd.img
mcopy -o -i "/tmp/test-hdd.img@@$((32*512))" /tmp/pc-flat.bin ::boot/loko
qemu-system-x86_64 -enable-kvm -m 2048 -M q35 -vga std -display none \
    -serial file:/tmp/boot.ser -drive file=/tmp/test-hdd.img,format=raw,if=ide
```

**结果**：串口打出 `Initializing Bochs graphics...`，REPL 窗口画出来，CPU 停在
`syscall-hlt` 的 `sti; hlt` 空转里；screendump 与 Loko 自己镜像的 screendump
只差 0.08% 像素（光标/时钟）。

参数和 Linux 那条不同：

| | Linux 路径 | 裸机路径 |
| --- | --- | --- |
| target | `-ftarget=sexp` | `-ftarget=sexp-pc` |
| 运行库 | `(loko … linux-*)` | `(loko … pc-*)`，`%call` 数为 0 |
| 镜像 | ELF（我们生成头/段表） | 平铺（`write-flat-image`） |
| 结果 | `/tmp/prog.elf` 直接跑 | 装进 `loko-hdd.img` 里由 syslinux 的 `mboot.c32` 加载 |

### 耗时（1.6M item 的 pc-repl 镜像，`loko-near`）

早期这条流水线要 **~50 分钟**，现在 **~21 秒**。都是同一类 bug：把"对所有
元素扫一遍"的操作放进逐 item 循环里。

| 层 | 之前 | 现在 | 原因 |
| --- | --- | --- | --- |
| `loko-lower` | 10 分钟（含机器争用） | 4 s | — |
| `dce` | 4–5 分钟 | 0.9 s | `(list-ref entries i)` / `(list-ref blocks (add1 i))` / `(length blocks)` 在逐块循环里 |
| `layout` | 5.5 分钟（更早 18 分钟） | 4.3 s | 逐 unit 的 `(list-ref flows bi)`、`(list-ref units (add1 i))`；更早还有规则表和 unit 累积 |
| `encode` | **39 分钟** | 3.6 s | `resolve-symbol` 对**每个**符号引用扫一遍全部符号表（22 万条） |

教训：本后端是"纯函数、无状态"的层层变换，很容易写出这种"每层内部看起来
O(1)"的代码；跑小镜像完全看不出来（linux 镜像 8.5 MB 只要 21 秒），只有
裸机镜像（44 MB dump）才暴露。

### 32 位引导段

裸机镜像开头的多引导 trampoline 是 `(%mode 32)`。本后端只有 64 位编码路径，
所以只放行"64 位路径编出的字节与 32 位一致"的 item（`loko-compatibility/mode32.rkt`
的审计清单：寄存器宽度 ≤32、没有 rip 相对、指令头在白名单里）。其余一律报
`mode32-unsupported-form`，不会静默编错。

### 一个真实踩过的坑：`hlt` 不是终止指令

Loko 的 `syscall-hlt` 是 `(sti) (hlt) (cli) (xor eax eax) (swapgs) (sysretq)`：
`hlt` 之后还要继续执行。早先 `compiler/analyze/insn.rkt` 把 `hlt` 归到
"不返回"（和 `ret`/`ud2` 一组），CFG 认为 `hlt` 后面的指令不可达，DCE 就把
`cli/swapgs/sysretq` 删了 —— 于是 `hlt` 醒来后**顺序落进下一条 syscall 实现**
（`syscall-rdmsr` 里的 `rdmsr`），用垃圾 MSR 号触发 #GP，而 #GP 的桩假定的是
用户态栈帧（`[rsp+0x20]` 取 RSP），内核态出错时那里是垃圾 → #DF。镜像能启动、
能初始化图形，然后死在这个 #DF 上。现象和根因隔得很远，教训是：
**"某条指令不会返回"这种事实必须和硬件语义一致**。

## 6. 注意

- `loko-near` 只用于正确性验证，不替代发布路径的 short+relax。
- dump/portableize 是 Loko 前端的外部工具，不属于 `compiler` 层。
- **不要用 `make -B loko` / `akku install` 之后再手工改 `.akku/lib/loko`**：`-B` 会重跑 `akku install`，而 akku 会把
  `.akku/lib/loko`（`LOKO_SOURCE` 指向的自有库目录）换成它自己的副本，
  打补丁的 `compiler/main.sls` 就丢了。正确做法是 `touch loko-prebuilt &&
  make loko`，并且保证 `.akku/lib/loko` 是**工作树的副本**（不是系统安装）。
- 验证顺序（每步都可单独失败）：dump 里的标记 → `translate-loko-source` 的
  `program-items`/`sections` 与旧 dump 一致 → `cache-loko-layout` → ELF → 执行。
