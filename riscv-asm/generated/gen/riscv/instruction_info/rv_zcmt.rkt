#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_zcmt-instructions
  (list
   (instruction-info 'cm.jalt 'rv_zcmt 16 2 '("c_index") '("c_index") '((0 1 2) (13 15 5) (10 12 0)) '() "cm.jalt c_index")))

(provide
 rv_zcmt-instructions)
