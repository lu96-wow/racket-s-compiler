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

(define vfwmaccbf16.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 59) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwmaccbf16.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 59) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))

(provide
 vfwmaccbf16.vv
 vfwmaccbf16.vf)
