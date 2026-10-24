#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_smrnmi-instructions
  (list
   (instruction-info 'mnret 'rv_smrnmi 32 4 '() '() '((7 11 0) (15 19 0) (20 31 1794) (12 14 0) (2 6 28) (0 1 3)) '() "mnret")))

(provide
 rv_smrnmi-instructions)
