#lang racket/base

(require "struct.rkt")

(define rv32_zilsd-instructions
  (list
   (instruction-info "ld" "rv32_zilsd" 32 '("rd_e" "rs1" "imm12") '("rd_e" "rs1" "imm12") '((12 14 3) (2 7 0) (0 1 3)) '() "ld rd_e, rs1, imm12")))

(provide
 rv32_zilsd-instructions)
