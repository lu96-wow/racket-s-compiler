#lang racket/base

(require "struct.rkt")

(define rv64_zacas-instructions
  (list
   (instruction-info "amocas.q" "rv64_zacas" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 1) (12 14 4) (2 6 11) (0 1 3)) '() "amocas.q rd, rs1, rs2, aq, rl")))

(provide rv64_zacas-instructions)
