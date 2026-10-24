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

(define lb.aq
  (make-instruction
   (list raw:rd raw:rs1 raw:rl)
   (list (bit-range-fixed 26 26 1) (bit-range-fixed 27 31 6) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define lh.aq
  (make-instruction
   (list raw:rd raw:rs1 raw:rl)
   (list (bit-range-fixed 26 26 1) (bit-range-fixed 27 31 6) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define lw.aq
  (make-instruction
   (list raw:rd raw:rs1 raw:rl)
   (list (bit-range-fixed 26 26 1) (bit-range-fixed 27 31 6) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define ld.aq
  (make-instruction
   (list raw:rd raw:rs1 raw:rl)
   (list (bit-range-fixed 26 26 1) (bit-range-fixed 27 31 6) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define sb.rl
  (make-instruction
   (list raw:rs1 raw:rs2 raw:aq)
   (list (bit-range-fixed 25 25 1) (bit-range-fixed 27 31 7) (bit-range-fixed 12 14 0) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define sh.rl
  (make-instruction
   (list raw:rs1 raw:rs2 raw:aq)
   (list (bit-range-fixed 25 25 1) (bit-range-fixed 27 31 7) (bit-range-fixed 12 14 1) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define sw.rl
  (make-instruction
   (list raw:rs1 raw:rs2 raw:aq)
   (list (bit-range-fixed 25 25 1) (bit-range-fixed 27 31 7) (bit-range-fixed 12 14 2) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define sd.rl
  (make-instruction
   (list raw:rs1 raw:rs2 raw:aq)
   (list (bit-range-fixed 25 25 1) (bit-range-fixed 27 31 7) (bit-range-fixed 12 14 3) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))

(provide
 lb.aq
 lh.aq
 lw.aq
 ld.aq
 sb.rl
 sh.rl
 sw.rl
 sd.rl)
