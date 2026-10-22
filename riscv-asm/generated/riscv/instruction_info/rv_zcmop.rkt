#lang racket/base

(require "struct.rkt")

(define rv_zcmop-instructions
  (list
   (instruction-info "c.mop.N" "rv_zcmop" 16 '("c_mop_t") '("c_mop_t") '((0 1 1) (2 6 0) (11 11 0) (7 7 1) (12 12 0) (13 15 3)) '() "c.mop.N c_mop_t")
   (instruction-info "c.mop.1" "rv_zcmop" 16 '() '() '((0 1 1) (2 6 0) (7 11 1) (12 12 0) (13 15 3)) '() "c.mop.1")
   (instruction-info "c.mop.3" "rv_zcmop" 16 '() '() '((0 1 1) (2 6 0) (7 11 3) (12 12 0) (13 15 3)) '() "c.mop.3")
   (instruction-info "c.mop.5" "rv_zcmop" 16 '() '() '((0 1 1) (2 6 0) (7 11 5) (12 12 0) (13 15 3)) '() "c.mop.5")
   (instruction-info "c.mop.7" "rv_zcmop" 16 '() '() '((0 1 1) (2 6 0) (7 11 7) (12 12 0) (13 15 3)) '() "c.mop.7")
   (instruction-info "c.mop.9" "rv_zcmop" 16 '() '() '((0 1 1) (2 6 0) (7 11 9) (12 12 0) (13 15 3)) '() "c.mop.9")
   (instruction-info "c.mop.11" "rv_zcmop" 16 '() '() '((0 1 1) (2 6 0) (7 11 11) (12 12 0) (13 15 3)) '() "c.mop.11")
   (instruction-info "c.mop.13" "rv_zcmop" 16 '() '() '((0 1 1) (2 6 0) (7 11 13) (12 12 0) (13 15 3)) '() "c.mop.13")
   (instruction-info "c.mop.15" "rv_zcmop" 16 '() '() '((0 1 1) (2 6 0) (7 11 15) (12 12 0) (13 15 3)) '() "c.mop.15")))

(provide
 rv_zcmop-instructions)
