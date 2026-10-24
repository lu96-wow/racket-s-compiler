#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/mop.rkt"))

(define vsm3c.vi
  (make-instruction
   (list raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 43) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsm3me.vv
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 32) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))

(provide
 vsm3c.vi
 vsm3me.vv)
