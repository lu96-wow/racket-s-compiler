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

(define c.jal
  (make-instruction
   (list raw:c_imm12)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 1))))
(define c.srli
  (make-instruction
   (list raw:rd_rs1_p raw:c_nzuimm5)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 0))))
(define c.srai
  (make-instruction
   (list raw:rd_rs1_p raw:c_nzuimm5)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 1))))
(define c.slli
  (make-instruction
   (list raw:rd_rs1_n0 raw:c_nzuimm6lo)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 12 15 0))))
(define c.srli_rv32
  (make-instruction
   (list raw:rd_rs1_p raw:c_nzuimm5)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 0))))
(define c.srai_rv32
  (make-instruction
   (list raw:rd_rs1_p raw:c_nzuimm5)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 1))))
(define c.slli_rv32
  (make-instruction
   (list raw:rd_rs1_n0 raw:c_nzuimm6lo)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 12 15 0))))

(provide
 c.jal
 c.srli
 c.srai
 c.slli
 c.srli_rv32
 c.srai_rv32
 c.slli_rv32)
