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

(define ssamoswap.w
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:aq raw:rl)
   (list (bit-range-fixed 29 31 2) (bit-range-fixed 27 28 1) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define ssamoswap.d
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:aq raw:rl)
   (list (bit-range-fixed 29 31 2) (bit-range-fixed 27 28 1) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define sspopchk.x1
  (make-instruction
   (list)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 15 19 1) (bit-range-fixed 12 14 4) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define sspopchk.x5
  (make-instruction
   (list)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 15 19 5) (bit-range-fixed 12 14 4) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define ssrdp
  (make-instruction
   (list raw:rd_n0)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define sspush.x1
  (make-instruction
   (list)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 1) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 4) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define sspush.x5
  (make-instruction
   (list)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 5) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 4) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 ssamoswap.w
 ssamoswap.d
 sspopchk.x1
 sspopchk.x5
 ssrdp
 sspush.x1
 sspush.x5)
