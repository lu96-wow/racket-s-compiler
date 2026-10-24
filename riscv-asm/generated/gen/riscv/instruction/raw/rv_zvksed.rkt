#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define vsm4k.vi
  (make-instruction
   (list vs2 zimm5 vd)
   (list (bit-range-fixed 26 31 33) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsm4r.vv
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 16) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsm4r.vs
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 16) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))

(provide
 vsm4k.vi
 vsm4r.vv
 vsm4r.vs)
