#lang racket/base

(require "struct.rkt")

(define rv_zbkc-instructions
  (list
   (instruction-info "clmul" "rv_zbkc" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 1) (2 6 12) (0 1 3)) '() "clmul rd, rs1, rs2")
   (instruction-info "clmulh" "rv_zbkc" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 3) (2 6 12) (0 1 3)) '() "clmulh rd, rs1, rs2")))

(provide
 rv_zbkc-instructions)
