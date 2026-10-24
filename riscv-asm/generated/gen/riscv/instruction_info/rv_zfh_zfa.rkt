#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_zfh_zfa-instructions
  (list
   (instruction-info 'fli.h 'rv_zfh_zfa 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 1) (27 31 30) (12 14 0) (25 26 2) (2 6 20) (0 1 3)) '() "fli.h rd, rs1")
   (instruction-info 'fminm.h 'rv_zfh_zfa 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 5) (12 14 2) (25 26 2) (2 6 20) (0 1 3)) '() "fminm.h rd, rs1, rs2")
   (instruction-info 'fmaxm.h 'rv_zfh_zfa 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 5) (12 14 3) (25 26 2) (2 6 20) (0 1 3)) '() "fmaxm.h rd, rs1, rs2")
   (instruction-info 'fround.h 'rv_zfh_zfa 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 4) (27 31 8) (25 26 2) (2 6 20) (0 1 3)) '() "fround.h rd, rs1, rm")
   (instruction-info 'froundnx.h 'rv_zfh_zfa 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 5) (27 31 8) (25 26 2) (2 6 20) (0 1 3)) '() "froundnx.h rd, rs1, rm")
   (instruction-info 'fleq.h 'rv_zfh_zfa 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 4) (25 26 2) (2 6 20) (0 1 3)) '() "fleq.h rd, rs1, rs2")
   (instruction-info 'fltq.h 'rv_zfh_zfa 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 5) (25 26 2) (2 6 20) (0 1 3)) '() "fltq.h rd, rs1, rs2")))

(provide
 rv_zfh_zfa-instructions)
