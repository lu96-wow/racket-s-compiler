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

(define sm4ed
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:bs)
   (list (bit-range-fixed 25 29 24) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sm4ks
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:bs)
   (list (bit-range-fixed 25 29 26) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))

(provide
 sm4ed
 sm4ks)
