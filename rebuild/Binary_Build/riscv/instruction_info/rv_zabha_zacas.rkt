#lang racket/base

(require "struct.rkt")

(define rv_zabha_zacas-instructions
  (list
   (instruction-info "amocas.b" "rv_zabha_zacas" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 1) (12 14 0) (2 6 11) (0 1 3)) '() "amocas.b rd, rs1, rs2, aq, rl")
   (instruction-info "amocas.h" "rv_zabha_zacas" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 1) (12 14 1) (2 6 11) (0 1 3)) '() "amocas.h rd, rs1, rs2, aq, rl")))

(provide
 rv_zabha_zacas-instructions)
