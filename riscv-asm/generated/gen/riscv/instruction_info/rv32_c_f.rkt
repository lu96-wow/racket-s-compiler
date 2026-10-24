#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv32_c_f-instructions
  (list
   (instruction-info 'c.flw 'rv32_c_f 16 2 '("rd_p" "rs1_p" "c_uimm7") '("rd_p" "rs1_p" "c_uimm7lo" "c_uimm7hi") '((0 1 0) (13 15 3)) '() "c.flw rd_p, rs1_p, c_uimm7")
   (instruction-info 'c.fsw 'rv32_c_f 16 2 '("rs1_p" "rs2_p" "c_uimm7") '("rs1_p" "rs2_p" "c_uimm7lo" "c_uimm7hi") '((0 1 0) (13 15 7)) '() "c.fsw rs1_p, rs2_p, c_uimm7")
   (instruction-info 'c.flwsp 'rv32_c_f 16 2 '("rd" "c_uimm8sp") '("rd" "c_uimm8sphi" "c_uimm8splo") '((0 1 2) (13 15 3)) '() "c.flwsp rd, c_uimm8sp")
   (instruction-info 'c.fswsp 'rv32_c_f 16 2 '("c_rs2" "c_uimm8sp_s") '("c_rs2" "c_uimm8sp_s") '((0 1 2) (13 15 7)) '() "c.fswsp c_rs2, c_uimm8sp_s")))

(provide
 rv32_c_f-instructions)
