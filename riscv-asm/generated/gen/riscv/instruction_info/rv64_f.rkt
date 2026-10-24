#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv64_f-instructions
  (list
   (instruction-info 'fcvt.l.s 'rv64_f 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 2) (27 31 24) (25 26 0) (2 6 20) (0 1 3)) '() "fcvt.l.s rd, rs1, rm")
   (instruction-info 'fcvt.lu.s 'rv64_f 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 3) (27 31 24) (25 26 0) (2 6 20) (0 1 3)) '() "fcvt.lu.s rd, rs1, rm")
   (instruction-info 'fcvt.s.l 'rv64_f 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 2) (27 31 26) (25 26 0) (2 6 20) (0 1 3)) '() "fcvt.s.l rd, rs1, rm")
   (instruction-info 'fcvt.s.lu 'rv64_f 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 3) (27 31 26) (25 26 0) (2 6 20) (0 1 3)) '() "fcvt.s.lu rd, rs1, rm")))

(provide
 rv64_f-instructions)
