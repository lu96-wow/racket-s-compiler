#lang racket/base

(require "struct.rkt")

(define rv_zawrs-instructions
  (list
   (instruction-info "wrs.nto" "rv_zawrs" 32 '() '() '((20 31 13) (7 19 0) (2 6 28) (0 1 3)) '() "wrs.nto")
   (instruction-info "wrs.sto" "rv_zawrs" 32 '() '() '((20 31 29) (7 19 0) (2 6 28) (0 1 3)) '() "wrs.sto")))

(provide
 rv_zawrs-instructions)
