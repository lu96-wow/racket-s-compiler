#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_s-instructions
  (list
   (instruction-info 'sfence.vma 'rv_s 32 4 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 9) (12 14 0) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rs1" "rs1") ("rs2" "rs2")) '(("raw:rs1" "rs1") ("raw:rs2" "rs2")) "sfence.vma rs1, rs2")
   (instruction-info 'sret 'rv_s 32 4 '() '() '((7 11 0) (15 19 0) (20 31 258) (12 14 0) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '() '() "sret")))

(provide
 rv_s-instructions)
