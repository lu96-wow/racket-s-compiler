#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_s-instructions
  (list
   (instruction-info 'sfence.vma 'rv_s 32 4 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 9) (12 14 0) (2 6 28) (0 1 3)) '() "sfence.vma rs1, rs2")
   (instruction-info 'sret 'rv_s 32 4 '() '() '((7 11 0) (15 19 0) (20 31 258) (12 14 0) (2 6 28) (0 1 3)) '() "sret")))

(provide
 rv_s-instructions)
