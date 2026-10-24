#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv64_zbs-instructions
  (list
   (instruction-info 'bclri 'rv64_zbs 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 18) (12 14 1) (2 6 4) (0 1 3)) '() "bclri rd, rs1, shamtd")
   (instruction-info 'bexti 'rv64_zbs 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 18) (12 14 5) (2 6 4) (0 1 3)) '() "bexti rd, rs1, shamtd")
   (instruction-info 'binvi 'rv64_zbs 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 26) (12 14 1) (2 6 4) (0 1 3)) '() "binvi rd, rs1, shamtd")
   (instruction-info 'bseti 'rv64_zbs 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 10) (12 14 1) (2 6 4) (0 1 3)) '() "bseti rd, rs1, shamtd")))

(provide
 rv64_zbs-instructions)
