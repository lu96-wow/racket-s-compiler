#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/mop.rkt"))

(define vfncvtbf16.f.f.w
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 29) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwcvtbf16.f.f.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 13) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))

(provide
 vfncvtbf16.f.f.w
 vfwcvtbf16.f.f.v)
