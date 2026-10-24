#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_ssctr-instructions
  (list
   (instruction-info 'sctrclr 'rv_ssctr 32 4 '() '() '((7 11 0) (15 19 0) (20 31 260) (12 14 0) (2 6 28) (0 1 3)) '() "sctrclr")))

(provide
 rv_ssctr-instructions)
