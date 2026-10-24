#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt"))

(define simm12
  (combine raw:imm12hi
           raw:imm12lo))
(define bimm12
  (combine raw:bimm12hi
           raw:bimm12lo))

(provide
 simm12
 bimm12)
