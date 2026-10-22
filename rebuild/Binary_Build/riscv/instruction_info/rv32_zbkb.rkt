#lang racket/base

(require "struct.rkt")

(define rv32_zbkb-instructions
  (list
   (instruction-info "zip" "rv32_zbkb" 32 '("rd" "rs1") '("rd" "rs1") '((25 31 4) (20 24 15) (12 14 1) (2 6 4) (0 1 3)) '() "zip rd, rs1")
   (instruction-info "unzip" "rv32_zbkb" 32 '("rd" "rs1") '("rd" "rs1") '((25 31 4) (20 24 15) (12 14 5) (2 6 4) (0 1 3)) '() "unzip rd, rs1")
   (instruction-info "rev8.rv32" "rv32_zbkb" 32 '("rd" "rs1") '("rd" "rs1") '((20 31 1688) (12 14 5) (0 6 19)) '() "rev8.rv32 rd, rs1")
   (instruction-info "rori.rv32" "rv32_zbkb" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 48) (12 14 5) (2 6 4) (0 1 3)) '() "rori.rv32 rd, rs1, shamtw")))

(provide rv32_zbkb-instructions)
