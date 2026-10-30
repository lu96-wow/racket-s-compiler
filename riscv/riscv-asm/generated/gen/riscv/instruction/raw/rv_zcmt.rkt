#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define cm.jalt
  (make-instruction
   (list c_index)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 5) (bit-range-fixed 10 12 0))))

(provide
 cm.jalt)
