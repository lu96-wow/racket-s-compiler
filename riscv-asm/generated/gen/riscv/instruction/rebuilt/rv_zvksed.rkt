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

(define vsm4k.vi
  (make-instruction
   (list raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 33) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsm4r.vv
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 16) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsm4r.vs
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 16) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))

(provide
 vsm4k.vi
 vsm4r.vv
 vsm4r.vs)
