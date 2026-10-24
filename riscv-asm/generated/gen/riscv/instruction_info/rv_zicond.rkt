#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_zicond-instructions
  (list
   (instruction-info 'czero.eqz 'rv_zicond 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 7) (12 14 5) (2 6 12) (0 1 3)) '() "czero.eqz rd, rs1, rs2")
   (instruction-info 'czero.nez 'rv_zicond 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 7) (12 14 7) (2 6 12) (0 1 3)) '() "czero.nez rd, rs1, rs2")))

(provide
 rv_zicond-instructions)
