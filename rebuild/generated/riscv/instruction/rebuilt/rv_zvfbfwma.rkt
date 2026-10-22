#lang racket/base

(require "../../../base.rkt"
         (prefix-in raw: "../../raw/scalar.rkt")
         (prefix-in raw: "../../raw/compressed.rkt")
         (prefix-in raw: "../../raw/vector.rkt")
         (prefix-in raw: "../../raw/mop.rkt")
         (prefix-in rebuilt: "../../rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../rebuilt/mop.rkt"))

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
