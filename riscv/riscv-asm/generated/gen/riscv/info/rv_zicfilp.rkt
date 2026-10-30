#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zicfilp-instructions
  (list
   (instruction-info 'lpad 'rv_zicfilp 32 4 '("imm20") '("imm20") '((7 11 0) (2 6 5) (0 1 3)) '() (instruction-origin 'pseudo 'rv_i 'auipc) '(("imm20" "imm20")) '(("raw:imm20" "imm20")) "lpad imm20")))

(provide
 rv_zicfilp-instructions)
