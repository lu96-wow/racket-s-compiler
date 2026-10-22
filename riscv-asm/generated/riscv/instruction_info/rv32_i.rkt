#lang racket/base

(require "struct.rkt")

(define rv32_i-instructions
  (list
   (instruction-info "slli" "rv32_i" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 0) (12 14 1) (2 6 4) (0 1 3)) '() "slli rd, rs1, shamtw")
   (instruction-info "srli" "rv32_i" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 0) (12 14 5) (2 6 4) (0 1 3)) '() "srli rd, rs1, shamtw")
   (instruction-info "srai" "rv32_i" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 32) (12 14 5) (2 6 4) (0 1 3)) '() "srai rd, rs1, shamtw")
   (instruction-info "slli_rv32" "rv32_i" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 0) (12 14 1) (2 6 4) (0 1 3)) '() "slli_rv32 rd, rs1, shamtw")
   (instruction-info "srli_rv32" "rv32_i" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 0) (12 14 5) (2 6 4) (0 1 3)) '() "srli_rv32 rd, rs1, shamtw")
   (instruction-info "srai_rv32" "rv32_i" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 32) (12 14 5) (2 6 4) (0 1 3)) '() "srai_rv32 rd, rs1, shamtw")))

(provide
 rv32_i-instructions)
