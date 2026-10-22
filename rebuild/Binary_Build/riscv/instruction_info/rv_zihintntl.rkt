#lang racket/base

(require "struct.rkt")

(define rv_zihintntl-instructions
  (list
   (instruction-info "ntl.p1" "rv_zihintntl" 32 '() '() '((25 31 0) (20 24 2) (15 19 0) (12 14 0) (7 11 0) (2 6 12) (0 1 3)) '() "ntl.p1")
   (instruction-info "ntl.pall" "rv_zihintntl" 32 '() '() '((25 31 0) (20 24 3) (15 19 0) (12 14 0) (7 11 0) (2 6 12) (0 1 3)) '() "ntl.pall")
   (instruction-info "ntl.s1" "rv_zihintntl" 32 '() '() '((25 31 0) (20 24 4) (15 19 0) (12 14 0) (7 11 0) (2 6 12) (0 1 3)) '() "ntl.s1")
   (instruction-info "ntl.all" "rv_zihintntl" 32 '() '() '((25 31 0) (20 24 5) (15 19 0) (12 14 0) (7 11 0) (2 6 12) (0 1 3)) '() "ntl.all")))

(provide rv_zihintntl-instructions)
