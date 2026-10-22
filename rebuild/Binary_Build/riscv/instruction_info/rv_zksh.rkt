#lang racket/base

(require "struct.rkt")

(define rv_zksh-instructions
  (list
   (instruction-info "sm3p0" "rv_zksh" 32 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 8) (12 14 1) (0 6 19)) '() "sm3p0 rd, rs1")
   (instruction-info "sm3p1" "rv_zksh" 32 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 9) (12 14 1) (0 6 19)) '() "sm3p1 rd, rs1")))

(provide
 rv_zksh-instructions)
