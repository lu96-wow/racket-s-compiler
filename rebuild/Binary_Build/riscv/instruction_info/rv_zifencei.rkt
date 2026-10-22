#lang racket/base

(require "struct.rkt")

(define rv_zifencei-instructions
  (list
   (instruction-info "fence.i" "rv_zifencei" 32 '("imm12" "rs1" "rd") '("imm12" "rs1" "rd") '((12 14 1) (2 6 3) (0 1 3)) '() "fence.i imm12, rs1, rd")))

(provide rv_zifencei-instructions)
