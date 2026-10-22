#lang racket/base

(require "struct.rkt")

(define rv_svinval-instructions
  (list
   (instruction-info "sinval.vma" "rv_svinval" 32 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 11) (12 14 0) (2 6 28) (0 1 3)) '() "sinval.vma rs1, rs2")
   (instruction-info "sfence.w.inval" "rv_svinval" 32 '() '() '((7 11 0) (15 19 0) (20 24 0) (25 31 12) (12 14 0) (2 6 28) (0 1 3)) '() "sfence.w.inval")
   (instruction-info "sfence.inval.ir" "rv_svinval" 32 '() '() '((7 11 0) (15 19 0) (20 24 1) (25 31 12) (12 14 0) (2 6 28) (0 1 3)) '() "sfence.inval.ir")))

(provide
 rv_svinval-instructions)
