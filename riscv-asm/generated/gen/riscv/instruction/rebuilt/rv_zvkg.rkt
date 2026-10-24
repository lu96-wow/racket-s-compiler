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

(define vgmul.vv
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 17) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vghsh.vv
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 44) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))

(provide
 vgmul.vv
 vghsh.vv)
