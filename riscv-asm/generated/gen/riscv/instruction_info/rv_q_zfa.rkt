#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_q_zfa-instructions
  (list
   (instruction-info 'fli.q 'rv_q_zfa 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 1) (27 31 30) (12 14 0) (25 26 3) (2 6 20) (0 1 3)) '() "fli.q rd, rs1")
   (instruction-info 'fminm.q 'rv_q_zfa 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 5) (12 14 2) (25 26 3) (2 6 20) (0 1 3)) '() "fminm.q rd, rs1, rs2")
   (instruction-info 'fmaxm.q 'rv_q_zfa 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 5) (12 14 3) (25 26 3) (2 6 20) (0 1 3)) '() "fmaxm.q rd, rs1, rs2")
   (instruction-info 'fround.q 'rv_q_zfa 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 4) (27 31 8) (25 26 3) (2 6 20) (0 1 3)) '() "fround.q rd, rs1, rm")
   (instruction-info 'froundnx.q 'rv_q_zfa 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 5) (27 31 8) (25 26 3) (2 6 20) (0 1 3)) '() "froundnx.q rd, rs1, rm")
   (instruction-info 'fleq.q 'rv_q_zfa 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 4) (25 26 3) (2 6 20) (0 1 3)) '() "fleq.q rd, rs1, rs2")
   (instruction-info 'fltq.q 'rv_q_zfa 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 5) (25 26 3) (2 6 20) (0 1 3)) '() "fltq.q rd, rs1, rs2")))

(provide
 rv_q_zfa-instructions)
