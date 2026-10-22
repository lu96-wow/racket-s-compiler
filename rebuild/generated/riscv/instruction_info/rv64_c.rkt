#lang racket/base

(require "struct.rkt")

(define rv64_c-instructions
  (list
   (instruction-info "c.ld" "rv64_c" 16 '("rd_p" "rs1_p" "c_uimm8") '("rd_p" "rs1_p" "c_uimm8lo" "c_uimm8hi") '((0 1 0) (13 15 3)) '() "c.ld rd_p, rs1_p, c_uimm8")
   (instruction-info "c.sd" "rv64_c" 16 '("rs1_p" "rs2_p" "c_uimm8") '("rs1_p" "rs2_p" "c_uimm8hi" "c_uimm8lo") '((0 1 0) (13 15 7)) '() "c.sd rs1_p, rs2_p, c_uimm8")
   (instruction-info "c.addiw" "rv64_c" 16 '("rd_rs1_n0" "c_imm6") '("rd_rs1_n0" "c_imm6lo" "c_imm6hi") '((0 1 1) (13 15 1)) '() "c.addiw rd_rs1_n0, c_imm6")
   (instruction-info "c.srli" "rv64_c" 16 '("rd_rs1_p" "c_nzuimm6") '("rd_rs1_p" "c_nzuimm6lo" "c_nzuimm6hi") '((0 1 1) (13 15 4) (10 11 0)) '() "c.srli rd_rs1_p, c_nzuimm6")
   (instruction-info "c.srai" "rv64_c" 16 '("rd_rs1_p" "c_nzuimm6") '("rd_rs1_p" "c_nzuimm6lo" "c_nzuimm6hi") '((0 1 1) (13 15 4) (10 11 1)) '() "c.srai rd_rs1_p, c_nzuimm6")
   (instruction-info "c.subw" "rv64_c" 16 '("rd_rs1_p" "rs2_p") '("rd_rs1_p" "rs2_p") '((0 1 1) (13 15 4) (10 12 7) (5 6 0)) '() "c.subw rd_rs1_p, rs2_p")
   (instruction-info "c.addw" "rv64_c" 16 '("rd_rs1_p" "rs2_p") '("rd_rs1_p" "rs2_p") '((0 1 1) (13 15 4) (10 12 7) (5 6 1)) '() "c.addw rd_rs1_p, rs2_p")
   (instruction-info "c.slli" "rv64_c" 16 '("rd_rs1_n0" "c_nzuimm6") '("rd_rs1_n0" "c_nzuimm6hi" "c_nzuimm6lo") '((0 1 2) (13 15 0)) '() "c.slli rd_rs1_n0, c_nzuimm6")
   (instruction-info "c.ldsp" "rv64_c" 16 '("rd_n0" "c_uimm9sp") '("rd_n0" "c_uimm9sphi" "c_uimm9splo") '((0 1 2) (13 15 3)) '() "c.ldsp rd_n0, c_uimm9sp")
   (instruction-info "c.sdsp" "rv64_c" 16 '("c_rs2" "c_uimm9sp_s") '("c_rs2" "c_uimm9sp_s") '((0 1 2) (13 15 7)) '() "c.sdsp c_rs2, c_uimm9sp_s")))

(provide
 rv64_c-instructions)
