#lang racket/base

(require "struct.rkt")

(define rv_m-instructions
  (list
   (instruction-info "mul" "rv_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 0) (2 6 12) (0 1 3)) '() "mul rd, rs1, rs2")
   (instruction-info "mulh" "rv_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 1) (2 6 12) (0 1 3)) '() "mulh rd, rs1, rs2")
   (instruction-info "mulhsu" "rv_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 2) (2 6 12) (0 1 3)) '() "mulhsu rd, rs1, rs2")
   (instruction-info "mulhu" "rv_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 3) (2 6 12) (0 1 3)) '() "mulhu rd, rs1, rs2")
   (instruction-info "div" "rv_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 4) (2 6 12) (0 1 3)) '() "div rd, rs1, rs2")
   (instruction-info "divu" "rv_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 5) (2 6 12) (0 1 3)) '() "divu rd, rs1, rs2")
   (instruction-info "rem" "rv_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 6) (2 6 12) (0 1 3)) '() "rem rd, rs1, rs2")
   (instruction-info "remu" "rv_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 7) (2 6 12) (0 1 3)) '() "remu rd, rs1, rs2")))

(provide
 rv_m-instructions)
