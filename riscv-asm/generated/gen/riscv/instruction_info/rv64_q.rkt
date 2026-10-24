#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv64_q-instructions
  (list
   (instruction-info 'fcvt.l.q 'rv64_q 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 2) (27 31 24) (25 26 3) (2 6 20) (0 1 3)) '() "fcvt.l.q rd, rs1, rm")
   (instruction-info 'fcvt.lu.q 'rv64_q 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 3) (27 31 24) (25 26 3) (2 6 20) (0 1 3)) '() "fcvt.lu.q rd, rs1, rm")
   (instruction-info 'fcvt.q.l 'rv64_q 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 2) (27 31 26) (25 26 3) (2 6 20) (0 1 3)) '() "fcvt.q.l rd, rs1, rm")
   (instruction-info 'fcvt.q.lu 'rv64_q 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 3) (27 31 26) (25 26 3) (2 6 20) (0 1 3)) '() "fcvt.q.lu rd, rs1, rm")))

(provide
 rv64_q-instructions)
