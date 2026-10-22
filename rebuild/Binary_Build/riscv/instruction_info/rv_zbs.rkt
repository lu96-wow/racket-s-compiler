#lang racket/base

(require "struct.rkt")

(define rv_zbs-instructions
  (list
   (instruction-info "bclr" "rv_zbs" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 36) (12 14 1) (2 6 12) (0 1 3)) '() "bclr rd, rs1, rs2")
   (instruction-info "bext" "rv_zbs" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 36) (12 14 5) (2 6 12) (0 1 3)) '() "bext rd, rs1, rs2")
   (instruction-info "binv" "rv_zbs" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 52) (12 14 1) (2 6 12) (0 1 3)) '() "binv rd, rs1, rs2")
   (instruction-info "bset" "rv_zbs" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 20) (12 14 1) (2 6 12) (0 1 3)) '() "bset rd, rs1, rs2")))

(provide rv_zbs-instructions)
