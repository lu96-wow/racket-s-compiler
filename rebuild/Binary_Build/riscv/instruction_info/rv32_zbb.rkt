#lang racket/base

(require "struct.rkt")

(define rv32_zbb-instructions
  (list
   (instruction-info "zext.h.rv32" "rv32_zbb" 32 '("rd" "rs1") '("rd" "rs1") '((25 31 4) (20 24 0) (12 14 4) (0 6 51)) '() "zext.h.rv32 rd, rs1")
   (instruction-info "rev8.rv32" "rv32_zbb" 32 '("rd" "rs1") '("rd" "rs1") '((20 31 1688) (12 14 5) (0 6 19)) '() "rev8.rv32 rd, rs1")
   (instruction-info "rori.rv32" "rv32_zbb" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 48) (12 14 5) (2 6 4) (0 1 3)) '() "rori.rv32 rd, rs1, shamtw")))

(provide rv32_zbb-instructions)
