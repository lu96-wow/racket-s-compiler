#lang racket/base

(require "struct.rkt")

(define rv_zacas-instructions
  (list
   (instruction-info "amocas.w" "rv_zacas" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 1) (12 14 2) (2 6 11) (0 1 3)) '() "amocas.w rd, rs1, rs2, aq, rl")
   (instruction-info "amocas.d" "rv_zacas" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 1) (12 14 3) (2 6 11) (0 1 3)) '() "amocas.d rd, rs1, rs2, aq, rl")))

(provide rv_zacas-instructions)
