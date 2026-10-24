#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_svinval-instructions
  (list
   (instruction-info 'sinval.vma 'rv_svinval 32 4 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 11) (12 14 0) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rs1" "rs1") ("rs2" "rs2")) '(("raw:rs1" "rs1") ("raw:rs2" "rs2")) "sinval.vma rs1, rs2")
   (instruction-info 'sfence.w.inval 'rv_svinval 32 4 '() '() '((7 11 0) (15 19 0) (20 24 0) (25 31 12) (12 14 0) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '() '() "sfence.w.inval")
   (instruction-info 'sfence.inval.ir 'rv_svinval 32 4 '() '() '((7 11 0) (15 19 0) (20 24 1) (25 31 12) (12 14 0) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '() '() "sfence.inval.ir")))

(provide
 rv_svinval-instructions)
