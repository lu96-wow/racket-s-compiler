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

(define vsha2ms.vv
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 45) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsha2ch.vv
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 46) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsha2cl.vv
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 47) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))

(provide
 vsha2ms.vv
 vsha2ch.vv
 vsha2cl.vv)
