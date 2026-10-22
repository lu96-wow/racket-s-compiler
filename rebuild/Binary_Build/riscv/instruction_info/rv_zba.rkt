#lang racket/base

(require "struct.rkt")

(define rv_zba-instructions
  (list
   (instruction-info "sh1add" "rv_zba" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 16) (12 14 2) (2 6 12) (0 1 3)) '() "sh1add rd, rs1, rs2")
   (instruction-info "sh2add" "rv_zba" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 16) (12 14 4) (2 6 12) (0 1 3)) '() "sh2add rd, rs1, rs2")
   (instruction-info "sh3add" "rv_zba" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 16) (12 14 6) (2 6 12) (0 1 3)) '() "sh3add rd, rs1, rs2")))

(provide rv_zba-instructions)
