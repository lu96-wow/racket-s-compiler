#lang racket/base

(require "struct.rkt")

(define rv_zabha-instructions
  (list
   (instruction-info "amoswap.b" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 0) (27 28 1) (12 14 0) (2 6 11) (0 1 3)) '() "amoswap.b rd, rs1, rs2, aq, rl")
   (instruction-info "amoadd.b" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 0) (27 28 0) (12 14 0) (2 6 11) (0 1 3)) '() "amoadd.b rd, rs1, rs2, aq, rl")
   (instruction-info "amoxor.b" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 0) (12 14 0) (2 6 11) (0 1 3)) '() "amoxor.b rd, rs1, rs2, aq, rl")
   (instruction-info "amoand.b" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 3) (27 28 0) (12 14 0) (2 6 11) (0 1 3)) '() "amoand.b rd, rs1, rs2, aq, rl")
   (instruction-info "amoor.b" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 2) (27 28 0) (12 14 0) (2 6 11) (0 1 3)) '() "amoor.b rd, rs1, rs2, aq, rl")
   (instruction-info "amomin.b" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 4) (27 28 0) (12 14 0) (2 6 11) (0 1 3)) '() "amomin.b rd, rs1, rs2, aq, rl")
   (instruction-info "amomax.b" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 5) (27 28 0) (12 14 0) (2 6 11) (0 1 3)) '() "amomax.b rd, rs1, rs2, aq, rl")
   (instruction-info "amominu.b" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 6) (27 28 0) (12 14 0) (2 6 11) (0 1 3)) '() "amominu.b rd, rs1, rs2, aq, rl")
   (instruction-info "amomaxu.b" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 7) (27 28 0) (12 14 0) (2 6 11) (0 1 3)) '() "amomaxu.b rd, rs1, rs2, aq, rl")
   (instruction-info "amoswap.h" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 0) (27 28 1) (12 14 1) (2 6 11) (0 1 3)) '() "amoswap.h rd, rs1, rs2, aq, rl")
   (instruction-info "amoadd.h" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 0) (27 28 0) (12 14 1) (2 6 11) (0 1 3)) '() "amoadd.h rd, rs1, rs2, aq, rl")
   (instruction-info "amoxor.h" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 0) (12 14 1) (2 6 11) (0 1 3)) '() "amoxor.h rd, rs1, rs2, aq, rl")
   (instruction-info "amoand.h" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 3) (27 28 0) (12 14 1) (2 6 11) (0 1 3)) '() "amoand.h rd, rs1, rs2, aq, rl")
   (instruction-info "amoor.h" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 2) (27 28 0) (12 14 1) (2 6 11) (0 1 3)) '() "amoor.h rd, rs1, rs2, aq, rl")
   (instruction-info "amomin.h" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 4) (27 28 0) (12 14 1) (2 6 11) (0 1 3)) '() "amomin.h rd, rs1, rs2, aq, rl")
   (instruction-info "amomax.h" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 5) (27 28 0) (12 14 1) (2 6 11) (0 1 3)) '() "amomax.h rd, rs1, rs2, aq, rl")
   (instruction-info "amominu.h" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 6) (27 28 0) (12 14 1) (2 6 11) (0 1 3)) '() "amominu.h rd, rs1, rs2, aq, rl")
   (instruction-info "amomaxu.h" "rv_zabha" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 7) (27 28 0) (12 14 1) (2 6 11) (0 1 3)) '() "amomaxu.h rd, rs1, rs2, aq, rl")))

(provide
 rv_zabha-instructions)
