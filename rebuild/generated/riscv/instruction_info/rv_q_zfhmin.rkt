#lang racket/base

(require "struct.rkt")

(define rv_q_zfhmin-instructions
  (list
   (instruction-info "fcvt.q.h" "rv_q_zfhmin" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 2) (27 31 8) (25 26 3) (2 6 20) (0 1 3)) '() "fcvt.q.h rd, rs1, rm")
   (instruction-info "fcvt.h.q" "rv_q_zfhmin" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 3) (27 31 8) (25 26 2) (2 6 20) (0 1 3)) '() "fcvt.h.q rd, rs1, rm")))

(provide
 rv_q_zfhmin-instructions)
