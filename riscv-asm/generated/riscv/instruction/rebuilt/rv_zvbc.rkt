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

(define vclmul.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 12) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vclmul.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 12) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vclmulh.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 13) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vclmulh.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 13) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))

(provide
 vclmul.vv
 vclmul.vx
 vclmulh.vv
 vclmulh.vx)
