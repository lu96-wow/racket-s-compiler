#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_c-instructions
  (list
   (instruction-info 'c.addi4spn 'rv_c 16 2 '("rd_p" "c_nzuimm10") '("rd_p" "c_nzuimm10") '((0 1 0) (13 15 0)) '() "c.addi4spn rd_p, c_nzuimm10")
   (instruction-info 'c.lw 'rv_c 16 2 '("rd_p" "rs1_p" "c_uimm7") '("rd_p" "rs1_p" "c_uimm7lo" "c_uimm7hi") '((0 1 0) (13 15 2)) '() "c.lw rd_p, rs1_p, c_uimm7")
   (instruction-info 'c.sw 'rv_c 16 2 '("rs1_p" "rs2_p" "c_uimm7") '("rs1_p" "rs2_p" "c_uimm7lo" "c_uimm7hi") '((0 1 0) (13 15 6)) '() "c.sw rs1_p, rs2_p, c_uimm7")
   (instruction-info 'c.nop 'rv_c 16 2 '("c_nzimm6") '("c_nzimm6hi" "c_nzimm6lo") '((0 1 1) (13 15 0) (7 11 0)) '() "c.nop c_nzimm6")
   (instruction-info 'c.addi 'rv_c 16 2 '("rd_rs1_n0" "c_nzimm6") '("rd_rs1_n0" "c_nzimm6lo" "c_nzimm6hi") '((0 1 1) (13 15 0)) '() "c.addi rd_rs1_n0, c_nzimm6")
   (instruction-info 'c.li 'rv_c 16 2 '("rd_n0" "c_imm6") '("rd_n0" "c_imm6lo" "c_imm6hi") '((0 1 1) (13 15 2)) '() "c.li rd_n0, c_imm6")
   (instruction-info 'c.addi16sp 'rv_c 16 2 '("c_nzimm10") '("c_nzimm10hi" "c_nzimm10lo") '((0 1 1) (13 15 3) (7 11 2)) '() "c.addi16sp c_nzimm10")
   (instruction-info 'c.lui 'rv_c 16 2 '("rd_n2" "c_nzimm18") '("rd_n2" "c_nzimm18hi" "c_nzimm18lo") '((0 1 1) (13 15 3)) '() "c.lui rd_n2, c_nzimm18")
   (instruction-info 'c.andi 'rv_c 16 2 '("rd_rs1_p" "c_imm6") '("rd_rs1_p" "c_imm6hi" "c_imm6lo") '((0 1 1) (13 15 4) (10 11 2)) '() "c.andi rd_rs1_p, c_imm6")
   (instruction-info 'c.sub 'rv_c 16 2 '("rd_rs1_p" "rs2_p") '("rd_rs1_p" "rs2_p") '((0 1 1) (13 15 4) (10 12 3) (5 6 0)) '() "c.sub rd_rs1_p, rs2_p")
   (instruction-info 'c.xor 'rv_c 16 2 '("rd_rs1_p" "rs2_p") '("rd_rs1_p" "rs2_p") '((0 1 1) (13 15 4) (10 12 3) (5 6 1)) '() "c.xor rd_rs1_p, rs2_p")
   (instruction-info 'c.or 'rv_c 16 2 '("rd_rs1_p" "rs2_p") '("rd_rs1_p" "rs2_p") '((0 1 1) (13 15 4) (10 12 3) (5 6 2)) '() "c.or rd_rs1_p, rs2_p")
   (instruction-info 'c.and 'rv_c 16 2 '("rd_rs1_p" "rs2_p") '("rd_rs1_p" "rs2_p") '((0 1 1) (13 15 4) (10 12 3) (5 6 3)) '() "c.and rd_rs1_p, rs2_p")
   (instruction-info 'c.j 'rv_c 16 2 '("c_imm12") '("c_imm12") '((0 1 1) (13 15 5)) '() "c.j c_imm12")
   (instruction-info 'c.beqz 'rv_c 16 2 '("rs1_p" "c_bimm9") '("rs1_p" "c_bimm9lo" "c_bimm9hi") '((0 1 1) (13 15 6)) '() "c.beqz rs1_p, c_bimm9")
   (instruction-info 'c.bnez 'rv_c 16 2 '("rs1_p" "c_bimm9") '("rs1_p" "c_bimm9lo" "c_bimm9hi") '((0 1 1) (13 15 7)) '() "c.bnez rs1_p, c_bimm9")
   (instruction-info 'c.lwsp 'rv_c 16 2 '("rd_n0" "c_uimm8sp") '("rd_n0" "c_uimm8sphi" "c_uimm8splo") '((0 1 2) (13 15 2)) '() "c.lwsp rd_n0, c_uimm8sp")
   (instruction-info 'c.jr 'rv_c 16 2 '("rs1_n0") '("rs1_n0") '((0 1 2) (13 15 4) (12 12 0) (2 6 0)) '() "c.jr rs1_n0")
   (instruction-info 'c.mv 'rv_c 16 2 '("rd_n0" "c_rs2_n0") '("rd_n0" "c_rs2_n0") '((0 1 2) (13 15 4) (12 12 0)) '() "c.mv rd_n0, c_rs2_n0")
   (instruction-info 'c.ebreak 'rv_c 16 2 '() '() '((0 1 2) (13 15 4) (12 12 1) (2 11 0)) '() "c.ebreak")
   (instruction-info 'c.jalr 'rv_c 16 2 '("c_rs1_n0") '("c_rs1_n0") '((0 1 2) (13 15 4) (12 12 1) (2 6 0)) '() "c.jalr c_rs1_n0")
   (instruction-info 'c.add 'rv_c 16 2 '("rd_rs1_n0" "c_rs2_n0") '("rd_rs1_n0" "c_rs2_n0") '((0 1 2) (13 15 4) (12 12 1)) '() "c.add rd_rs1_n0, c_rs2_n0")
   (instruction-info 'c.swsp 'rv_c 16 2 '("c_rs2" "c_uimm8sp_s") '("c_rs2" "c_uimm8sp_s") '((0 1 2) (13 15 6)) '() "c.swsp c_rs2, c_uimm8sp_s")))

(provide
 rv_c-instructions)
