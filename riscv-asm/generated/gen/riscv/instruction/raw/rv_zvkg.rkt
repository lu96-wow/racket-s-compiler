#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define vgmul.vv
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 17) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vghsh.vv
  (make-instruction
   (list vs2 vs1 vd)
   (list (bit-range-fixed 26 31 44) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))

(provide
 vgmul.vv
 vghsh.vv)
