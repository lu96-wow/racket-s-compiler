# tools

这些工具只为**验证**：把真实 Loko 的 assembler 输出接到本后端，并避免每次
重跑整条编译流水线。

现在的链路只有三段（`--engine` 那条历史路线见第 5 节）：

```text
Loko (-ftarget=sexp)  ->  dump.sexp
       ↓ tools/loko-flow.rkt        流水线 + 产物缓存
   <cache>/encode.rktd  或  <cache>/loko-elf.rktd
       ↓ tools/write-flat-image.rkt / tools/write-cached-elf.rkt
   平铺镜像 / ELF
```

## 1. 导出 Loko 程序：`sexp` target

Loko 树里装一次 target 插件（源码在 Loko 仓库 `arch/amd64/sexp-asm.sls`，
本仓库不保留副本）：

```sh
tools/build-loko-target.sh          # 装 target + 自举重建 loko-prebuilt
```

它用 Loko 公开的 `(loko arch asm) register-target` 接口注册 `sexp` / `sexp-pc`
两个 target：不发射 ELF 头/段表、不产字节，直接把 assembler 输入写成 Racket
能读的 s-expression（label/gensym 按**对象身份**编号，vector/bytevector/字符
用自己的 printer，所以不需要任何文本后处理）。

```sh
# Linux ELF 用的 dump
LOKO_PROGRAM_SEXP=/tmp/prog.sexp ./loko-prebuilt -ftarget=sexp \
    --compile program.sps --output /tmp/prog.bin

# 裸机（pc）用的 dump
cd bin/pc-repl && LOKO_PROGRAM_SEXP=/tmp/pc.sexp .akku/env ../../loko-prebuilt \
    -feval -ftarget=sexp-pc --compile pc-repl.sps --output /tmp/pc.bin
```

`get-scheme-libraries` 必须把 `(sexp)` 映射成 `linux`（`compiler/static.sls`），
否则 `linux-start`/`elf-start`/syscall 那几个库不会进程序：镜像能链接能跑，
但启动就对着小整数解引用（实测 SIGBUS，`rax=0x2f`）。

## 2. 读 dump：`loko-compatibility/sexp-read.rkt`

dump 是"一行一个 item"的 s-expression 文本。`read` 能读，但 44 MB /
1,615,886 个 item / 950 万个 token 要 **10–12 s**，时间几乎全花在"每个 token
先造一个 string 再 `string->symbol` / `string->number`"上：

| 事实 | 数字 |
| --- | --- |
| 符号实例 | 3,976,593（只有 257,583 种拼写，15 倍重复；最多的是 `mov` 43 万） |
| 整数 | 1,150,766（最长 19 位，只有 16,379 个超出 fixnum） |
| bytevector | 58,681（平均 82 字节） |
| 字符串 / 字符 | 1,057 / 275 |

`read-dump` 直接扫字节：符号按 `(bytes, start, len)` 查自建 intern 表（命中
零分配），整数就地累加，bytevector 就地解码；只有 flonum、带转义的字符串、
`|…|` 符号、字符名这些"`read` 才说得准"的东西才退回 `read`。

```sh
racket -e '(require (file "loko-compatibility/sexp-read.rkt")) \
           (displayln (length (read-dump "/tmp/pc.sexp")))'
# 1615886
```

| dump | `read` | `read-dump` |
| --- | --- | --- |
| pc-repl 44 MB | 10.5–12.4 s | **2.4 s** |
| linux 8.5 MB | 2.3 s | **0.44 s** |

判据只有一条：**和 `read` 读出来逐 item `equal?`**。快是目的，读得不一样就是
错。`loko-compatibility/sexp-read-test.rkt` 用一段覆盖各种写法的语料 + 可选
真实 dump 验这件事：

```sh
LS_EXPECT_DUMP=/tmp/pc.sexp racket tools/run-test.rkt \
    loko-compatibility/sexp-read-test.rkt
```

踩过的坑（都在测试里有用例）：`#\x41` 是字符 `x` 后面跟整数 41、`#true` 是
`#t` 后面跟 `rue`、`0.0` 是 flonum 而 `|0.0|` 是符号、`#[const value: …]` 是
vector（Racket 的 reader 把 `#[` 当 `#(`）、`(` 和 `[` 混着写是错误不是宽容。
所以慢路径不截 token 喂给 `read`，而是让它从同一个 port 的同一位置读，按它
实际吃到哪儿继续。

## 3. 流水线 + 产物缓存：`tools/loko-flow.rkt`、`tools/flow-cache.rkt`

```sh
# pc / 裸机：loko-near = 全 near 分支 + 只 layout 一次（不跑 relax）。
# 这个 near 变体层 expand-pseudo-near 注册在 loko-compatibility/flow.rkt 里：
# 它是这条验证流的策略，核心流只有 expand-pseudo 一个。
racket tools/loko-flow.rkt /tmp/pc.sexp /tmp/pcflow loko-near
# -> /tmp/pcflow/encode.rktd    （encode 的 build：各段字节）

# linux / ELF（elf：short 起步 + relax + writer）
racket tools/loko-flow.rkt /tmp/prog.sexp /tmp/elfcache elf
# -> /tmp/elfcache/loko-elf.rktd（loko-elf 的 image：ELF 字节 + 入口）

# 之后落盘，不再重跑流水线
racket tools/write-flat-image.rkt /tmp/pcflow/encode.rktd /tmp/pc-flat.bin
racket tools/write-cached-elf.rkt /tmp/elfcache/loko-elf.rktd /tmp/prog.elf
```

缓存的是**这次流水的产物**（最后一层的输出），不是中间层。这个结论是量出来的：

| 方案 | 缓存体积 | 命中耗时 | 全量重算 |
| --- | --- | --- | --- |
| 逐层缓存（旧的 `loko-flow`） | 443 MB | 189 s | 21 s |
| 只缓存产物（现在） | 17 MB | **1.7 s** | 21 s + 2.4 s 解析 |

逐层缓存的 189 s 全花在 `deserialize` 逐层重建那些 list 上（compat 112 MB→39 s、
bind 76 MB→24 s、lower 66 MB→22 s、image 57 MB→19 s……）；而流水线本身在前面的
二次复杂度修掉之后只要 21 s。**缓存中间层是纯负优化**——所以现在连 dump 都不解析：
命中路径只 stat 一下 dump 和几个源目录。

失效条件（`flow-cache.rkt` 开头有完整说明）：

| 变了什么 | 怎么发现 |
| --- | --- |
| 缓存文件格式 | `format-version` 整数 |
| 流水线语义 | `stage-version` 整数（改编译器就 +1） |
| 选了哪些层 | `loko-near` 和 `loko` 的 `build` 不是一回事，必须进 key |
| 输入 dump | 绝对路径 + 大小 + mtime |
| 流水线源码 | `compiler/` 等目录里 `*.rkt` 的 (最大 mtime, 个数) |

`stage-version` 和源文件指纹是重叠的：前者是"我知道我改了什么"，后者是
"你忘了 +1 也不会拿到假结果"。两个都只在命中路径上花几毫秒。

两个选项（要写在位置参数**前面**，`racket/cmdline` 的 `. rest` 之后不再解析）：

```sh
racket tools/loko-flow.rkt --refresh /tmp/pc.sexp /tmp/pcflow loko-near  # 忽略缓存
racket tools/loko-flow.rkt --verify  /tmp/pc.sexp /tmp/pcflow loko-near  # 重跑核对
```

`--verify` 会重跑一遍并逐字节比较产物——怀疑缓存键漏了什么的时候用它。

## 4. 已验证

`tests/test-bugs.sps` 走完整链路（`-ftarget=sexp` → `loko-flow … loko-near` →
`write-flat-image`/`write-cached-elf`），产物跑出 `Tests passed`；pc-repl 的
平铺镜像与改造前的验证镜像**逐字节相同**（7,286,784 B）。

布局改成"由 layout 求解地址"之后，ELF 也重跑过同一条链路：产物与旧路径
**逐字节相同**（3,763,416 B）。原因：真实 Loko 程序的 section 尺寸恰好是页的
整数倍，旧的"紧凑打包"本来就落在页边界上；新规则把这些边界变成结构性的
（由 plan 的 `(align 4096)` 兑现），而不是靠尺寸凑巧。

小程序的差别很大：没有 `%elf` 时后端会合成默认 plan，段很小、以前会挤在同一页，
内核把 `.bss` 的匿名页盖在 `.text` 上 → 入口 SIGSEGV。这条路径由
`tools/smoke-loko-elf.rkt` 守住（构建 + 真执行 + 每段独占一页）。

## 5. 历史：dump 补丁 + portableize（不再需要）

`sexp` target 出现之前，这条路是"往 Loko 的 `compiler/main.sls` 里加 dump 钩子，
再用 python 做文本清洗"：

| 当时需要 | 为什么现在不需要了 |
| --- | --- |
| `tools/loko-dump.patch` | 不再往 `compiler/main.sls` 里加 dump 钩子 |
| `tools/loko-portableize.py` | 我们自己的 printer 直接吐可读形式 |
| `%call` / `%elf-header` / `%elf-tail` 标记 | target 根本不发射汇编期 ELF writer 的内容 |

两个文件保留着是为了读旧的 dump（和旧日志对账），**新流程不要用**。它们解决的
问题各有意思，记在这里免得再踩：

- `%call` 是汇编期闭包（`(%call proc arg …)`，`proc` 拿到
  `assemble!/ip/symbols/bss` 直接发 item 并返回位置增量），不可序列化。Loko 里
  它的三处用途**全部是 ELF writer**（头回卷、strtab、symtab），所以补丁把这两段
  换成 `(%elf-header)` / `(%elf-tail)` 两个声明式标记，`loko-compat` 直接丢掉了
  （`strip-elf-wrapper`）。裸的 `%call` 仍然报 `directive-needs-image-layer`。
- label 是 vector、gensym 是 uninterned symbol，必须按**对象身份**编号，不能按
  打印文本（同名不同对象会撞）。portableize 时代靠 python 正则改文本，现在由
  target 自己编号（`loko-obj-vector-N` / `loko-gensym-N`）。
- Loko 的字符串转义用 `\xHEX;`（`;` 是终止符），Racket 的 `\x` 只吃两个十六
  进制位，直接搬会多出一个 `;`。

`.akku/lib/loko` 是 akku 的构建产物，`build-loko-target.sh` 会用"工作树副本 +
系统安装里的生成文件"重建它；**不要**手工 `rm -rf` 它之后跑 `make -B`（那会把
工作树里的库文件换成悬空符号链接）。

## 6. 在 QEMU 里跑产物（整机，不是用户态）

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

## 6.1 裸机（pc / multiboot）镜像

同一个后端也能产 Loko 的**裸机**镜像。一条命令：

```sh
# 默认读 ~/work/tmp/loko，产出 /tmp/pc-flat.bin 和装好的磁盘副本
./tools/build-pc-image.sh            # 只构建
./tools/build-pc-image.sh -b         # 构建 + 启动 QEMU/KVM，检查 REPL 画出来了
```

脚本从零跑一遍约 6 分钟（大头是 Loko 侧 dump）；dump 没变时流水线命中产物
缓存只要 **1.7 s**，直接 `write-flat-image` 落盘。下面是分步说明，每一步都能
单独跑。

链路和 Linux 那条平行：

```sh
# 1. Loko 侧 dump（sexp-pc target 在 Loko 仓库 arch/amd64/sexp-asm.sls）
cd ~/work/tmp/loko/bin/pc-repl
LOKO_PROGRAM_SEXP=/tmp/pc.sexp .akku/env ../../loko-prebuilt \
    -feval -ftarget=sexp-pc --compile pc-repl.sps --output /tmp/pc.bin

# 2. 我们的流水线（产物缓存；这个镜像 1.6M 个 item，冷跑 24 s，命中 1.7 s）
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

早期这条流水线要 **~50 分钟**，现在**冷跑 ~24 秒、命中缓存 1.7 秒**。都是同一
类 bug：把"对所有元素扫一遍"的操作放进逐 item 循环里。

| 层 | 之前 | 现在 | 原因 |
| --- | --- | --- | --- |
| dump 解析（`read`） | 12.4 s | 2.4 s | 每个 token 造 string 再 `string->symbol`；改成扫字节 + intern 表 |
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

## 7. 注意

- `loko-near` 只用于正确性验证，不替代发布路径的 short+relax。
- dump 由 Loko 的 `sexp` / `sexp-pc` target 产出（源码在 Loko 仓库
  `arch/amd64/sexp-asm.sls`）；`sexp-read.rkt` 只有 `loko-compatibility` 用，
  `compiler/` 不认识 dump 文本。
- **不要用 `make -B loko` / `akku install` 之后再手工改 `.akku/lib/loko`**：`-B` 会重跑 `akku install`，而 akku 会把
  `.akku/lib/loko`（`LOKO_SOURCE` 指向的自有库目录）换成它自己的副本，
  打补丁的 `compiler/main.sls` 就丢了。正确做法是 `touch loko-prebuilt &&
  make loko`，并且保证 `.akku/lib/loko` 是**工作树的副本**（不是系统安装）。
- 验证顺序（每步都可单独失败）：dump 里的标记 → `translate-loko-source` 的
  `program-items`/`sections` 与旧 dump 一致 → `loko-flow.rkt` → ELF → 执行。
