#lang racket/base

(require "struct.rkt")

(define rv32_zknh-instructions
  (list
   (instruction-info "sha512sum0r" "rv32_zknh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 8) (12 14 0) (0 6 51)) '() "sha512sum0r rd, rs1, rs2")
   (instruction-info "sha512sum1r" "rv32_zknh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 9) (12 14 0) (0 6 51)) '() "sha512sum1r rd, rs1, rs2")
   (instruction-info "sha512sig0l" "rv32_zknh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 10) (12 14 0) (0 6 51)) '() "sha512sig0l rd, rs1, rs2")
   (instruction-info "sha512sig0h" "rv32_zknh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 14) (12 14 0) (0 6 51)) '() "sha512sig0h rd, rs1, rs2")
   (instruction-info "sha512sig1l" "rv32_zknh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 11) (12 14 0) (0 6 51)) '() "sha512sig1l rd, rs1, rs2")
   (instruction-info "sha512sig1h" "rv32_zknh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 15) (12 14 0) (0 6 51)) '() "sha512sig1h rd, rs1, rs2")))

(provide rv32_zknh-instructions)
