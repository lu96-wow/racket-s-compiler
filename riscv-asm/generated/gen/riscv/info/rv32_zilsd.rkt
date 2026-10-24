#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv32_zilsd-instructions
  (list
   (instruction-info 'ld 'rv32_zilsd 32 4 '("rd_e" "rs1" "imm12") '("rd_e" "rs1" "imm12") '((12 14 3) (2 7 0) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_i 'ld) '(("rd_e" "rd_e") ("rs1" "rs1") ("imm12" "imm12")) '(("raw:rd_e" "rd_e") ("raw:rs1" "rs1") ("raw:imm12" "imm12")) "ld rd_e, rs1, imm12")))

(provide
 rv32_zilsd-instructions)
