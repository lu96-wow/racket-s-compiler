#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv64_zfh-instructions
  (list
   (instruction-info 'fcvt.l.h 'rv64_zfh 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 2) (27 31 24) (25 26 2) (2 6 20) (0 1 3)) '() "fcvt.l.h rd, rs1, rm")
   (instruction-info 'fcvt.lu.h 'rv64_zfh 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 3) (27 31 24) (25 26 2) (2 6 20) (0 1 3)) '() "fcvt.lu.h rd, rs1, rm")
   (instruction-info 'fcvt.h.l 'rv64_zfh 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 2) (27 31 26) (25 26 2) (2 6 20) (0 1 3)) '() "fcvt.h.l rd, rs1, rm")
   (instruction-info 'fcvt.h.lu 'rv64_zfh 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 3) (27 31 26) (25 26 2) (2 6 20) (0 1 3)) '() "fcvt.h.lu rd, rs1, rm")))

(provide
 rv64_zfh-instructions)
