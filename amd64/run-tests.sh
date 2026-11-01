#!/bin/sh
set -eu
cd "$(dirname "$0")"

# Compile modules once; reruns then load .zo instead of expanding source.
raco make \
  amd64-asm/*.rkt \
  amd64-asm/special/*.rkt \
  amd64-help/*.rkt \
  amd64-elf/*.rkt \
  compiler/*/*.rkt \
  loko-compatibility/*.rkt \
  loko-compatibility/*/*.rkt \
  tools/*.rkt

failed=''
for test in \
  amd64-asm/test.rkt \
  amd64-asm/test-oracle.rkt \
  amd64-asm/test-generated.rkt \
  amd64-help/test.rkt \
  amd64-elf/test.rkt \
  compiler/expand-data/test.rkt \
  compiler/flatten/test.rkt \
  compiler/expand-pseudo/test.rkt \
  compiler/analyze/test.rkt \
  compiler/layout/test.rkt \
  compiler/relax/test.rkt \
  compiler/test/item-test.rkt \
  compiler/test/end-to-end.rkt \
  compiler/test/flow-test.rkt \
  loko-compatibility/test.rkt \
  loko-compatibility/test-flow.rkt \
  loko-compatibility/lower/test.rkt \
  loko-compatibility/image/test.rkt \
  tools/smoke-loko-elf.rkt
do
  printf '== %s\n' "$test"
  # 用 run-test.rkt 跑: rackunit 的 check-* 失败本身不改退出码，包装器会。
  # 单个测试失败不中断，跑完再一起报告，方便一次看到全部问题。
  if ! racket tools/run-test.rkt "$test"; then
    failed="$failed $test"
  fi
done

# 可选：QEMU 整机冒烟（真内核 + 真 boot，不是用户态直接运行）。
# 需要 /dev/kvm；镜像用 QEMU_SMOKE_ELF=/path/to.elf 指定，不指定就不跑。
if [ -n "${QEMU_SMOKE_ELF:-}" ]; then
  printf '== tools/qemu-run.sh %s\n' "$QEMU_SMOKE_ELF"
  if ! ./tools/qemu-run.sh "$QEMU_SMOKE_ELF"; then
    failed="$failed qemu-run"
  fi
fi

if [ -n "${failed:-}" ]; then
  printf '\nFAILED:%s\n' "$failed" >&2
  exit 1
fi
printf '\nall tests passed\n' 
