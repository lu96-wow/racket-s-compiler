#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define vfwmaccbf16.vv
  (make-instruction
   (list vm vs2 vs1 vd)
   (list (bit-range-fixed 26 31 59) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwmaccbf16.vf
  (make-instruction
   (list vm vs2 rs1 vd)
   (list (bit-range-fixed 26 31 59) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))

(provide
 vfwmaccbf16.vv
 vfwmaccbf16.vf)
