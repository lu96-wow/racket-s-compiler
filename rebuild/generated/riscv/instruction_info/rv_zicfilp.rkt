#lang racket/base

(require "struct.rkt")

(define rv_zicfilp-instructions
  (list
   (instruction-info "lpad" "rv_zicfilp" 32 '("imm20") '("imm20") '((7 11 0) (2 6 5) (0 1 3)) '() "lpad imm20")))

(provide
 rv_zicfilp-instructions)
