#!/bin/sh
# 重建带 "sexp" target 的 Loko（这个 target 让 Loko 直接吐 s-expression IR，
# 镜像交给我们的 amd64 后端）。
#
# 用法: tools/build-loko-target.sh [/path/to/loko]
#
# sexp target 的源在 **Loko 仓库里**（arch/amd64/sexp-asm.sls，和 linux-asm.sls
# 放一起），本仓库不再保留副本，避免两处漂移。安装面共 4 处：
#
#   1. arch/amd64/sexp-asm.sls                   新文件
#   2. compile-loko.sps                          +2 行（import + sexp-asm:visit）
#   3. compiler/static.sls                       静态库列表 +1 行
#   4. compiler/static.sls                       get-scheme-libraries: [(sexp) '(linux)]
#
# 第 4 条是踩过的坑：get-scheme-libraries 按 target-kernel 决定链接哪些运行库，
# 少了它 kernels 为空 -> linux-start / linux-init / elf-start 都不进程序，
# 编出来的镜像启动就 SIGBUS。
#
# 不要用 `make loko-prebuilt`（Chez 路径，需要 akku 的 .loko.sls 布局，还会被
# runtime/parameters.chezscheme.sls 抢先加载）。这里用自举两步，已验证可行。
set -eu

LOKO=${1:-${LOKO:-$HOME/work/tmp/loko}}
SYS=${LOKO_SYSTEM_LIB:-/usr/local/lib/loko/loko}   # 生成文件（unicode 表/字体…）的来源

[ -f "$LOKO/compile-loko.sps" ] || { echo "not a loko tree: $LOKO" >&2; exit 1; }

echo "== 检查 4 处安装面"
[ -f "$LOKO/arch/amd64/sexp-asm.sls" ] \
  || { echo "缺 arch/amd64/sexp-asm.sls" >&2; exit 1; }
grep -q 'sexp-asm:visit' "$LOKO/compile-loko.sps" \
  || { echo "compile-loko.sps 缺 sexp-asm 的 import/visit" >&2; exit 1; }
grep -q 'loko/arch/amd64/sexp-asm' "$LOKO/compiler/static.sls" \
  || { echo "compiler/static.sls 缺 sexp-asm 的静态库条目" >&2; exit 1; }
grep -q "\[(sexp) '(linux)\]" "$LOKO/compiler/static.sls" \
  || { echo "compiler/static.sls 缺 [(sexp) '(linux)]，镜像会启动即崩" >&2; exit 1; }

echo "== 用工作树重建 .akku/lib/loko（akku 的构建目录）+ 补齐生成文件"
rm -rf "$LOKO/.akku/lib/loko"
mkdir -p "$LOKO/.akku/lib/loko"
( cd "$LOKO" && tar -cf - --exclude=.git --exclude=.akku \
      --exclude=./loko --exclude=./loko.old --exclude='./loko-prebuilt*' \
      --exclude=./compile-loko --exclude='*.out' . ) \
  | ( cd "$LOKO/.akku/lib/loko" && tar -xf - )
if [ -d "$SYS" ]; then
  ( cd "$SYS" && find . -type f ) | while read -r f; do
    if [ ! -f "$LOKO/.akku/lib/loko/$f" ]; then
      mkdir -p "$LOKO/.akku/lib/loko/$(dirname "$f")"
      rm -f "$LOKO/.akku/lib/loko/$f"        # 树里可能是悬空符号链接
      cp -L "$SYS/$f" "$LOKO/.akku/lib/loko/$f"
    fi
  done
fi

echo "== 自举两步：loko -> compile-loko -> loko-prebuilt"
cd "$LOKO"
( ulimit -v 3000000; timeout 300 env LOKO_SOURCE=.akku/lib .akku/env \
    ./loko -feval --compile compile-loko.sps )
( ulimit -v 3000000; timeout 300 env LOKO_SOURCE=.akku/lib .akku/env ./compile-loko )
chmod +x loko-prebuilt.out
mv -f loko-prebuilt loko-prebuilt.old
mv -f loko-prebuilt.out loko-prebuilt
rm -f compile-loko

echo
echo "两个后端："
echo "  原 Loko:  ./loko-prebuilt -ftarget=linux --compile prog.sps --output prog.bin"
echo "  我们的:   LOKO_PROGRAM_SEXP=/tmp/prog.sexp ./loko-prebuilt -ftarget=sexp \\"
echo "                --compile prog.sps --output /tmp/prog.bin"
echo "            racket tools/cache-loko-layout.rkt /tmp/prog.sexp /tmp/prog.cache loko-near"
echo "            racket tools/write-cached-elf.rkt /tmp/prog.cache /tmp/prog.elf"
