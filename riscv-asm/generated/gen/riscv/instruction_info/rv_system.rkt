#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_system-instructions
  (list
   (instruction-info 'mret 'rv_system 32 4 '() '() '((7 11 0) (15 19 0) (20 31 770) (12 14 0) (2 6 28) (0 1 3)) '() "mret")
   (instruction-info 'wfi 'rv_system 32 4 '() '() '((7 11 0) (15 19 0) (20 31 261) (12 14 0) (2 6 28) (0 1 3)) '() "wfi")))

(provide
 rv_system-instructions)
