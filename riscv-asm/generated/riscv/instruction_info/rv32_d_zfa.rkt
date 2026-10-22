#lang racket/base

(require "struct.rkt")

(define rv32_d_zfa-instructions
  (list
   (instruction-info "fmvh.x.d" "rv32_d_zfa" 32 '("rd" "rs1") '("rd" "rs1") '((20 24 1) (27 31 28) (12 14 0) (25 26 1) (2 6 20) (0 1 3)) '() "fmvh.x.d rd, rs1")
   (instruction-info "fmvp.d.x" "rv32_d_zfa" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 22) (12 14 0) (25 26 1) (2 6 20) (0 1 3)) '() "fmvp.d.x rd, rs1, rs2")))

(provide
 rv32_d_zfa-instructions)
