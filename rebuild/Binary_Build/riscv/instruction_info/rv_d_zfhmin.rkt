#lang racket/base

(require "struct.rkt")

(define rv_d_zfhmin-instructions
  (list
   (instruction-info "fcvt.d.h" "rv_d_zfhmin" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 2) (27 31 8) (25 26 1) (2 6 20) (0 1 3)) '() "fcvt.d.h rd, rs1, rm")
   (instruction-info "fcvt.h.d" "rv_d_zfhmin" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 1) (27 31 8) (25 26 2) (2 6 20) (0 1 3)) '() "fcvt.h.d rd, rs1, rm")))

(provide rv_d_zfhmin-instructions)
