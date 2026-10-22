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

(define flh
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 1) (bit-range-fixed 0 1 3))))
(define fsh
  (let ([encode (make-instruction
   (list rebuilt:simm12 raw:rs1 raw:rs2 rebuilt:simm12)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 9) (bit-range-fixed 0 1 3)))])
    (lambda (simm12 rs1 rs2)
      (encode simm12 rs1 rs2 simm12))))
(define fcvt.s.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 2) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.h.s
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.x.h
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 28) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.h.x
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 30) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))

(provide
 flh
 fsh
 fcvt.s.h
 fcvt.h.s
 fmv.x.h
 fmv.h.x)
