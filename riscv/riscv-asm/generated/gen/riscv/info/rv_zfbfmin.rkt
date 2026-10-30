#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zfbfmin-instructions
  (list
   (instruction-info 'fcvt.bf16.s 'rv_zfbfmin 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 8) (27 31 8) (25 26 2) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rm" "rm")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rm" "rm")) "fcvt.bf16.s rd, rs1, rm")
   (instruction-info 'fcvt.s.bf16 'rv_zfbfmin 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 6) (27 31 8) (25 26 0) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rm" "rm")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rm" "rm")) "fcvt.s.bf16 rd, rs1, rm")))

(provide
 rv_zfbfmin-instructions)
