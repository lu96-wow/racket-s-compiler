#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define vfncvtbf16.f.f.w
  (make-instruction
   (list vm vs2 vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 29) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwcvtbf16.f.f.v
  (make-instruction
   (list vm vs2 vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 13) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))

(provide
 vfncvtbf16.f.f.w
 vfwcvtbf16.f.f.v)
