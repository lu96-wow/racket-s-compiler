#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_zvfbfwma-instructions
  (list
   (instruction-info 'vfwmaccbf16.vv 'rv_zvfbfwma 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 59) (12 14 1) (0 6 87)) '() "vfwmaccbf16.vv vm, vs2, vs1, vd")
   (instruction-info 'vfwmaccbf16.vf 'rv_zvfbfwma 32 4 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 59) (12 14 5) (0 6 87)) '() "vfwmaccbf16.vf vm, vs2, rs1, vd")))

(provide
 rv_zvfbfwma-instructions)
