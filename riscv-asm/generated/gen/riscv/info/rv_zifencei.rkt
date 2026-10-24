#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zifencei-instructions
  (list
   (instruction-info 'fence.i 'rv_zifencei 32 4 '("imm12" "rs1" "rd") '("imm12" "rs1" "rd") '((12 14 1) (2 6 3) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("imm12" "imm12") ("rs1" "rs1") ("rd" "rd")) '(("raw:imm12" "imm12") ("raw:rs1" "rs1") ("raw:rd" "rd")) "fence.i imm12, rs1, rd")))

(provide
 rv_zifencei-instructions)
