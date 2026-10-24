#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_c_zihintntl-instructions
  (list
   (instruction-info 'c.ntl.p1 'rv_c_zihintntl 16 2 '() '() '((0 1 2) (2 6 2) (7 11 0) (13 15 4) (12 12 1)) '() "c.ntl.p1")
   (instruction-info 'c.ntl.pall 'rv_c_zihintntl 16 2 '() '() '((0 1 2) (2 6 3) (7 11 0) (13 15 4) (12 12 1)) '() "c.ntl.pall")
   (instruction-info 'c.ntl.s1 'rv_c_zihintntl 16 2 '() '() '((0 1 2) (2 6 4) (7 11 0) (13 15 4) (12 12 1)) '() "c.ntl.s1")
   (instruction-info 'c.ntl.all 'rv_c_zihintntl 16 2 '() '() '((0 1 2) (2 6 5) (7 11 0) (13 15 4) (12 12 1)) '() "c.ntl.all")))

(provide
 rv_c_zihintntl-instructions)
