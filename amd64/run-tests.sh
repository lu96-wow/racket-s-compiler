#!/bin/sh
set -eu
cd "$(dirname "$0")"

# Compile modules once; reruns then load .zo instead of expanding source.
raco make \
  amd64-asm/*.rkt \
  amd64-help/*.rkt \
  amd64-elf/*.rkt \
  compiler/*/*.rkt \
  loko-compatibility/*.rkt \
  loko-compatibility/*/*.rkt \
  tools/*.rkt

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
  compiler/test/end-to-end.rkt \
  compiler/test/flow-test.rkt \
  loko-compatibility/test.rkt \
  loko-compatibility/test-flow.rkt \
  loko-compatibility/lower/test.rkt \
  loko-compatibility/image/test.rkt
do
  printf '== %s\n' "$test"
  racket "$test"
done
