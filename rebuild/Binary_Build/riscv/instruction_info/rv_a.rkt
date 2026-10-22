#lang racket/base

(require "struct.rkt")

(define rv_a-instructions
  (list
   (instruction-info "lr.w" "rv_a" 32 '("rd" "rs1" "aq" "rl") '("rd" "rs1" "aq" "rl") '((20 24 0) (29 31 0) (27 28 2) (12 14 2) (2 6 11) (0 1 3)) '() "lr.w rd, rs1, aq, rl")
   (instruction-info "sc.w" "rv_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 0) (27 28 3) (12 14 2) (2 6 11) (0 1 3)) '() "sc.w rd, rs1, rs2, aq, rl")
   (instruction-info "amoswap.w" "rv_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 0) (27 28 1) (12 14 2) (2 6 11) (0 1 3)) '() "amoswap.w rd, rs1, rs2, aq, rl")
   (instruction-info "amoadd.w" "rv_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 0) (27 28 0) (12 14 2) (2 6 11) (0 1 3)) '() "amoadd.w rd, rs1, rs2, aq, rl")
   (instruction-info "amoxor.w" "rv_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 0) (12 14 2) (2 6 11) (0 1 3)) '() "amoxor.w rd, rs1, rs2, aq, rl")
   (instruction-info "amoand.w" "rv_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 3) (27 28 0) (12 14 2) (2 6 11) (0 1 3)) '() "amoand.w rd, rs1, rs2, aq, rl")
   (instruction-info "amoor.w" "rv_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 2) (27 28 0) (12 14 2) (2 6 11) (0 1 3)) '() "amoor.w rd, rs1, rs2, aq, rl")
   (instruction-info "amomin.w" "rv_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 4) (27 28 0) (12 14 2) (2 6 11) (0 1 3)) '() "amomin.w rd, rs1, rs2, aq, rl")
   (instruction-info "amomax.w" "rv_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 5) (27 28 0) (12 14 2) (2 6 11) (0 1 3)) '() "amomax.w rd, rs1, rs2, aq, rl")
   (instruction-info "amominu.w" "rv_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 6) (27 28 0) (12 14 2) (2 6 11) (0 1 3)) '() "amominu.w rd, rs1, rs2, aq, rl")
   (instruction-info "amomaxu.w" "rv_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 7) (27 28 0) (12 14 2) (2 6 11) (0 1 3)) '() "amomaxu.w rd, rs1, rs2, aq, rl")))

(provide rv_a-instructions)
