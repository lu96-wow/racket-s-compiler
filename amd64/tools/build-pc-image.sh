#!/bin/sh
# 从 Loko 的 pc-repl 源码到能启动的裸机镜像，一条命令。
#
# 用法: tools/build-pc-image.sh [-b] [-o out.img] [loko 树]
#
#   默认 Loko 树是 $HOME/work/tmp/loko
#   -b   构建完顺便用 QEMU/KVM 启动一次，检查 REPL 画出来了（screendump 非黑）
#   -o   把装好镜像的磁盘副本放到这个路径（默认 /tmp/loko-hdd-ours.img）
#
# 步骤（每一步都能单独跑）：
#   1. Loko 侧 dump:      -ftarget=sexp-pc  -> /tmp/pc.sexp
#   2. 我们的流水线:      tools/loko-flow.rkt   （逐层缓存）
#   3. 平铺镜像:          tools/write-flat-image.rkt（会核对 multiboot 头）
#   4. 装进磁盘镜像副本:  mtools 替换 FAT 分区里的 boot/loko
#
# 前置条件：Loko 树里已经装了 sexp-pc target（tools/build-loko-target.sh），
# 并且 bin/pc-repl/loko-hdd.img 已经构建过（`cd bin/pc-repl && make loko-hdd.img`）。
set -eu

BOOT=0
OUT=/tmp/loko-hdd-ours.img
while [ $# -gt 0 ]; do
    case $1 in
        -b) BOOT=1; shift ;;
        -o) OUT=$2; shift 2 ;;
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) break ;;
    esac
done

HERE=$(cd "$(dirname "$0")" && pwd)
LOKO=${1:-${LOKO:-$HOME/work/tmp/loko}}
DUMP=${DUMP:-/tmp/pc.sexp}
CACHE=${CACHE:-/tmp/pcflow}

[ -f "$LOKO/bin/pc-repl/pc-repl.sps" ] || { echo "$0: not a loko tree: $LOKO" >&2; exit 1; }
[ -f "$LOKO/bin/pc-repl/loko-hdd.img" ] || { echo "$0: 先构建磁盘镜像: cd $LOKO/bin/pc-repl && make loko-hdd.img" >&2; exit 1; }
grep -q 'sexp-pc' "$LOKO/arch/amd64/sexp-asm.sls" \
    || { echo "$0: Loko 树里没有 sexp-pc target，先跑 tools/build-loko-target.sh" >&2; exit 1; }

echo "== 1. dump ($LOKO/bin/pc-repl/pc-repl.sps)"
( cd "$LOKO/bin/pc-repl" \
  && ulimit -v 4000000 && \
     env LOKO_SOURCE="$LOKO/.akku/lib" R6RS_PATH="$LOKO/.akku/lib" \
         LOKO_PROGRAM_SEXP="$DUMP" \
         .akku/env ../../loko-prebuilt -feval -ftarget=sexp-pc \
         --compile pc-repl.sps --output /tmp/pc.bin )
ls -l "$DUMP"

echo "== 2. 流水线（逐层缓存，第二次起很快）"
( cd "$HERE/.." && ulimit -v 8000000 && racket tools/loko-flow.rkt "$DUMP" "$CACHE" loko-near )

echo "== 3. 平铺镜像 + multiboot 头检查"
( cd "$HERE/.." && racket tools/write-flat-image.rkt "$CACHE/encode.rktd" /tmp/pc-flat.bin )

echo "== 4. 装进磁盘镜像副本 $OUT"
cp "$LOKO/bin/pc-repl/loko-hdd.img" "$OUT"
mcopy -o -i "$OUT@@$((32*512))" /tmp/pc-flat.bin ::boot/loko
mdir -i "$OUT@@$((32*512))" -a ::/boot | grep loko

[ "$BOOT" = 1 ] || { echo "完成。启动: qemu-system-x86_64 -enable-kvm -m 2048 -M q35 -vga std -display none -serial stdio -drive file=$OUT,format=raw,if=ide"; exit 0; }

echo "== 5. 启动 45 秒，检查串口和屏幕"
MON=/tmp/pc-mon.$$
rm -f "$MON" /tmp/pc-boot.ser /tmp/pc-screen.ppm
( ulimit -v 8000000; timeout 90 qemu-system-x86_64 -enable-kvm -m 2048 -M q35 \
    -vga std -display none -serial file:/tmp/pc-boot.ser \
    -drive "file=$OUT,format=raw,if=ide" \
    -monitor "unix:$MON,server,nowait" >/dev/null 2>&1 & )
sleep 45
python3 - "$MON" <<'PY'
import re, socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); time.sleep(0.3); s.recv(65536)
def cmd(c):
    s.sendall((c + "\n").encode()); time.sleep(2)
    out = b""; s.settimeout(2)
    try:
        while True:
            d = s.recv(65536)
            if not d: break
            out += d
    except Exception: pass
    return re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', out.decode(errors="replace"))
info = cmd("info registers")
print("  CPU:", (re.search(r"RIP=([0-9a-f]+)", info) or [None, "?"])[1],
      "HLT=" + (re.search(r"HLT=(\d)", info) or [None, "?"])[1])
cmd("screendump /tmp/pc-screen.ppm")
cmd("quit")
PY
rm -f "$MON"
sed -n '1,100p' /tmp/pc-boot.ser | tr -d '\r' | tail -3
python3 - <<'PY'
try:
    d = open("/tmp/pc-screen.ppm", "rb").read()
except FileNotFoundError:
    print("没有 screendump（QEMU 没起来？）"); raise SystemExit(1)
parts = d.split(b"\n", 3)
px = parts[3]
step = 3 * 97
nonblack = sum(1 for i in range(0, len(px), step) if px[i:i+3] != b"\x00\x00\x00")
total = len(range(0, len(px), step))
print("  屏幕抽样非黑像素: %d/%d" % (nonblack, total))
if nonblack * 10 < total:
    print("  REPL 没画出来"); raise SystemExit(1)
print("  REPL 在跑")
PY
