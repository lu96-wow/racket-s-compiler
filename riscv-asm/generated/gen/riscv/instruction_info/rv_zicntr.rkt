#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_zicntr-instructions
  (list
   (instruction-info 'rdcycle 'rv_zicntr 32 4 '("rd") '("rd") '((15 19 0) (20 31 3072) (12 14 2) (2 6 28) (0 1 3)) '() "rdcycle rd")
   (instruction-info 'rdtime 'rv_zicntr 32 4 '("rd") '("rd") '((15 19 0) (20 31 3073) (12 14 2) (2 6 28) (0 1 3)) '() "rdtime rd")
   (instruction-info 'rdinstret 'rv_zicntr 32 4 '("rd") '("rd") '((15 19 0) (20 31 3074) (12 14 2) (2 6 28) (0 1 3)) '() "rdinstret rd")))

(provide
 rv_zicntr-instructions)
