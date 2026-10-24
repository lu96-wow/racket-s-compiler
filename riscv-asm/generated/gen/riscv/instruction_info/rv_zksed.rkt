#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_zksed-instructions
  (list
   (instruction-info 'sm4ed 'rv_zksed 32 4 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 24) (12 14 0) (0 6 51)) '() "sm4ed rd, rs1, rs2, bs")
   (instruction-info 'sm4ks 'rv_zksed 32 4 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 26) (12 14 0) (0 6 51)) '() "sm4ks rd, rs1, rs2, bs")))

(provide
 rv_zksed-instructions)
