#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv64_zbkb-instructions
  (list
   (instruction-info 'packw 'rv64_zbkb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 4) (12 14 4) (2 6 14) (0 1 3)) '() "packw rd, rs1, rs2")
   (instruction-info 'rolw 'rv64_zbkb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 1) (2 6 14) (0 1 3)) '() "rolw rd, rs1, rs2")
   (instruction-info 'rorw 'rv64_zbkb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 5) (2 6 14) (0 1 3)) '() "rorw rd, rs1, rs2")
   (instruction-info 'roriw 'rv64_zbkb 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 48) (12 14 5) (2 6 6) (0 1 3)) '() "roriw rd, rs1, shamtw")
   (instruction-info 'rori 'rv64_zbkb 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 24) (12 14 5) (2 6 4) (0 1 3)) '() "rori rd, rs1, shamtd")
   (instruction-info 'rev8 'rv64_zbkb 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 1720) (12 14 5) (0 6 19)) '() "rev8 rd, rs1")))

(provide
 rv64_zbkb-instructions)
