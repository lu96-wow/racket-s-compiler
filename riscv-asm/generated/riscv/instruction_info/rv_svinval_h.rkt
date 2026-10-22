#lang racket/base

(require "struct.rkt")

(define rv_svinval_h-instructions
  (list
   (instruction-info "hinval.vvma" "rv_svinval_h" 32 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 19) (12 14 0) (2 6 28) (0 1 3)) '() "hinval.vvma rs1, rs2")
   (instruction-info "hinval.gvma" "rv_svinval_h" 32 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 51) (12 14 0) (2 6 28) (0 1 3)) '() "hinval.gvma rs1, rs2")))

(provide
 rv_svinval_h-instructions)
