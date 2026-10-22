#lang racket/base

(require "struct.rkt")

(define rv32_zknd-instructions
  (list
   (instruction-info "aes32dsmi" "rv32_zknd" 32 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 23) (12 14 0) (0 6 51)) '() "aes32dsmi rd, rs1, rs2, bs")
   (instruction-info "aes32dsi" "rv32_zknd" 32 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 21) (12 14 0) (0 6 51)) '() "aes32dsi rd, rs1, rs2, bs")))

(provide
 rv32_zknd-instructions)
