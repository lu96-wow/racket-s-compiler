#lang racket/base

(require "struct.rkt")

(define rv32_zbs-instructions
  (list
   (instruction-info "bclri.rv32" "rv32_zbs" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 36) (12 14 1) (2 6 4) (0 1 3)) '() "bclri.rv32 rd, rs1, shamtw")
   (instruction-info "bexti.rv32" "rv32_zbs" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 36) (12 14 5) (2 6 4) (0 1 3)) '() "bexti.rv32 rd, rs1, shamtw")
   (instruction-info "binvi.rv32" "rv32_zbs" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 52) (12 14 1) (2 6 4) (0 1 3)) '() "binvi.rv32 rd, rs1, shamtw")
   (instruction-info "bseti.rv32" "rv32_zbs" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 20) (12 14 1) (2 6 4) (0 1 3)) '() "bseti.rv32 rd, rs1, shamtw")))

(provide rv32_zbs-instructions)
