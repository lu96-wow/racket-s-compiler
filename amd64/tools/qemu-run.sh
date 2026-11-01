#!/bin/sh
# 在 QEMU 里跑一个本后端（amd64/sexp target）产出的静态 ELF。
#
# 用法: tools/qemu-run.sh /path/to/prog.elf [程序参数…]
#
# 做法：把 prog.elf 当 /prog 塞进一个最小 initramfs（busybox + 它的动态库），
# 用宿主机的 vmlinuz 当 -kernel 启动，init 跑程序并把退出码打印出来，
# 脚本再把这个退出码当自己的退出码。所以这是"整机 + 真内核"路径，
# 能查出用户态直接运行查不出的问题（入口地址、段权限、页重叠、内核 ABI）。
#
# 环境变量：
#   QEMU_ACCEL   kvm（默认）| tcg      —— 见下面"为什么不能用 tcg"
#   QEMU_MEM     guest 内存 MB（默认 2048）
#   QEMU_CPUS    vCPU 数（默认 2）
#   KERNEL       内核镜像（默认 /boot/vmlinuz-$(uname -r)）
#   BUSYBOX      静态/动态 busybox 都可（默认 /usr/bin/busybox）
#   QEMU_TIMEOUT 秒（默认 120）
#
# 为什么不能用 tcg：Loko 启动时会验证 #AC（对齐检查）真的会触发 SIGBUS
# （arch/amd64/linux-init.sls 的 linux-init-check-alignment）。QEMU 的 TCG
# 不实现 AC 标志，未对齐访问不陷入，于是程序以 exit 70 打印
# "Fatal: Loko can't run because the system does not support #AC." 后退出。
# KVM 里是硬件行为，正常工作。
#
# 为什么至少要 2 GB：Loko 的堆是启动时 mmap 的 1 GiB（MAP_FIXED 到高地址），
# 内核按 overcommit 记账，guest 只有 1 GB 时 mmap 直接 ENOMEM。
# 这个 ENOMEM 是真实的（不是 QEMU 的怪癖），错误信息长这样：
#   function: mmap / errno: 12 / &irritants: (1100853805056 1073741824 3 50 -1 0)
#   （0x10020000000, 1 GiB, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS）
set -eu

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
[ $# -ge 1 ] || usage
ELF=$1; shift

ACCEL=${QEMU_ACCEL:-kvm}
MEM=${QEMU_MEM:-2048}
CPUS=${QEMU_CPUS:-2}
KERNEL=${KERNEL:-/boot/vmlinuz-$(uname -r)}
BUSYBOX=${BUSYBOX:-/usr/bin/busybox}
TIMEOUT=${QEMU_TIMEOUT:-120}

[ -f "$ELF" ] || { echo "$0: $ELF: no such file" >&2; exit 1; }
[ -f "$KERNEL" ] || { echo "$0: $KERNEL: 没有内核镜像，设 KERNEL=/boot/vmlinuz-..." >&2; exit 1; }
[ -x "$BUSYBOX" ] || { echo "$0: $BUSYBOX: 需要 busybox" >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null 2>&1 \
  || { echo "$0: 没装 qemu-system-x86_64" >&2; exit 1; }

if [ "$ACCEL" = kvm ] && [ ! -w /dev/kvm ]; then
    echo "$0: /dev/kvm 不可写，改用 tcg（会撞上 #AC 检查，见文件头）" >&2
    ACCEL=tcg
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/qemu-run.XXXXXX")
trap 'rm -rf "$WORK"' EXIT INT TERM
ROOT=$WORK/root
mkdir -p "$ROOT"/bin "$ROOT"/lib "$ROOT"/lib64 "$ROOT"/proc "$ROOT"/dev "$ROOT"/tmp

cp "$ELF" "$ROOT/prog"
chmod +x "$ROOT/prog"
cp "$BUSYBOX" "$ROOT/bin/busybox"

# busybox 可能是动态链接的：按 ldd 的路径原样搬进去
ldd "$BUSYBOX" 2>/dev/null | while read -r line; do
    case $line in
        *'=> /'*) lib=${line#*=> }; lib=${lib%% (*} ;;
        /*)       lib=${line%% (*} ;;
        *)        continue ;;
    esac
    [ -f "$lib" ] || continue
    mkdir -p "$ROOT$(dirname "$lib")"
    cp -L "$lib" "$ROOT$lib"
done

# init：跑程序，打印退出码，然后关机（panic=-1 不用，正常 poweroff）
{
    echo '#!/bin/busybox sh'
    echo '/bin/busybox --install -s /bin'
    echo 'mount -t proc proc /proc'
    echo 'mount -t devtmpfs dev /dev'
    echo 'echo "=== prog start"'
    printf '/prog'
    for a in "$@"; do printf ' %s' "$a"; done
    echo
    echo 'echo "=== exit=$?"'
    echo 'sync'
    echo 'poweroff -f'
} > "$ROOT/init"
chmod +x "$ROOT/init"

( cd "$ROOT" && find . | cpio -o -H newc 2>/dev/null | gzip -1 > "$WORK/initrd.cpio.gz" )

if [ "$ACCEL" = kvm ]; then
    CPU=${QEMU_CPU:-host}
else
    CPU=${QEMU_CPU:-max}      # -cpu host 只支持 KVM/HVF
fi

LOG=$WORK/qemu.log
set +e
timeout "$TIMEOUT" qemu-system-x86_64 \
    -accel "$ACCEL" -cpu "$CPU" -M q35 -m "$MEM" -smp "$CPUS" \
    -nographic -no-reboot \
    -kernel "$KERNEL" -initrd "$WORK/initrd.cpio.gz" \
    -append "console=ttyS0 loglevel=4 rdinit=/init" >"$LOG" 2>&1
QEMU_STATUS=$?
set -e

# 程序输出 = "=== prog start" 与 "=== exit=" 之间的内容（内核日志已被 loglevel=4 压掉）。
# 先把 ANSI 转义（SeaBIOS/内核清屏）去掉，否则标记行会带前缀。
LOG2=$(tr -d '\r' <"$LOG" | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g')
if ! echo "$LOG2" | grep -q '=== prog start'; then
    echo "qemu 没有跑起来（qemu 退出码 $QEMU_STATUS）：" >&2
    sed -n '1,40p' "$LOG" | tr -d '\r' >&2
    exit 1
fi
OUT=$(echo "$LOG2" | awk '/=== prog start/{on=1; next} /=== exit=/{on=0} on')
echo "$OUT" | grep -v '^\[ *[0-9.]*\]' || true
EXIT=$(echo "$LOG2" | sed -n 's/.*=== exit=\([0-9]*\).*/\1/p' | tail -1)

# 这两条不是 QEMU 的问题，是 Loko 运行库的前提（详见 README 第 5 节）
if echo "$OUT" | grep -q 'does not support #AC'; then
    echo "\n注意: 这个 accel（$ACCEL）不实现 #AC。Loko 的运行库靠 #AC 做类型错误恢复，" >&2
    echo "      启动时会验证一次，所以任何 Loko 镜像都不能在这种环境下跑。" >&2
    echo "      改用 QEMU_ACCEL=kvm，或直接在 CPU 上跑这个 ELF（不需要 QEMU）。" >&2
fi
if echo "$OUT" | grep -q 'function: mmap' && echo "$OUT" | grep -q 'errno: 12'; then
    echo "\n注意: guest 内存不够装 Loko 的 1 GiB 堆，把 QEMU_MEM 调到 2048 以上。" >&2
fi
[ -n "$EXIT" ] || { echo "$0: 没拿到退出码，日志在 $LOG" >&2; exit 1; }
exit "$EXIT"
