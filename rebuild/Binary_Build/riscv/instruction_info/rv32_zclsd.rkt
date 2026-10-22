#lang racket/base

(require "struct.rkt")

(define rv32_zclsd-instructions
  (list
   (instruction-info "c.ld" "rv32_zclsd" 16 '("rd_p_e" "rs1_p" "c_uimm8") '("rd_p_e" "rs1_p" "c_uimm8lo" "c_uimm8hi") '((0 2 0) (13 15 3)) '() "c.ld rd_p_e, rs1_p, c_uimm8")
   (instruction-info "c.sd" "rv32_zclsd" 16 '("rs1_p" "rs2_p_e" "c_uimm8") '("rs1_p" "rs2_p_e" "c_uimm8hi" "c_uimm8lo") '((0 2 0) (13 15 7)) '() "c.sd rs1_p, rs2_p_e, c_uimm8")
   (instruction-info "c.ldsp" "rv32_zclsd" 16 '("rd_n0_e" "c_uimm9sp") '("rd_n0_e" "c_uimm9sphi" "c_uimm9splo") '((0 1 2) (13 15 3) (7 7 0)) '() "c.ldsp rd_n0_e, c_uimm9sp")
   (instruction-info "c.sdsp" "rv32_zclsd" 16 '("c_rs2_e" "c_uimm9sp_s") '("c_rs2_e" "c_uimm9sp_s") '((0 2 2) (13 15 7)) '() "c.sdsp c_rs2_e, c_uimm9sp_s")))

(provide rv32_zclsd-instructions)
