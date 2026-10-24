#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_zfbfmin-instructions
  (list
   (instruction-info 'fcvt.bf16.s 'rv_zfbfmin 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 8) (27 31 8) (25 26 2) (2 6 20) (0 1 3)) '() "fcvt.bf16.s rd, rs1, rm")
   (instruction-info 'fcvt.s.bf16 'rv_zfbfmin 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 6) (27 31 8) (25 26 0) (2 6 20) (0 1 3)) '() "fcvt.s.bf16 rd, rs1, rm")))

(provide
 rv_zfbfmin-instructions)
