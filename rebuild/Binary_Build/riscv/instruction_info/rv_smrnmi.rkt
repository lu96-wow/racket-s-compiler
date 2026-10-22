#lang racket/base

(require "struct.rkt")

(define rv_smrnmi-instructions
  (list
   (instruction-info "mnret" "rv_smrnmi" 32 '() '() '((7 11 0) (15 19 0) (20 31 1794) (12 14 0) (2 6 28) (0 1 3)) '() "mnret")))

(provide rv_smrnmi-instructions)
