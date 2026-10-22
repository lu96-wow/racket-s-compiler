#lang racket/base

(require "struct.rkt")

(define rv32_zkne-instructions
  (list
   (instruction-info "aes32esmi" "rv32_zkne" 32 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 19) (12 14 0) (0 6 51)) '() "aes32esmi rd, rs1, rs2, bs")
   (instruction-info "aes32esi" "rv32_zkne" 32 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 17) (12 14 0) (0 6 51)) '() "aes32esi rd, rs1, rs2, bs")))

(provide rv32_zkne-instructions)
