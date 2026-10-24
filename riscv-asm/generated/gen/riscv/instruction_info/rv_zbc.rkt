#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_zbc-instructions
  (list
   (instruction-info 'clmul 'rv_zbc 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 1) (2 6 12) (0 1 3)) '() "clmul rd, rs1, rs2")
   (instruction-info 'clmulr 'rv_zbc 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 2) (2 6 12) (0 1 3)) '() "clmulr rd, rs1, rs2")
   (instruction-info 'clmulh 'rv_zbc 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 3) (2 6 12) (0 1 3)) '() "clmulh rd, rs1, rs2")))

(provide
 rv_zbc-instructions)
