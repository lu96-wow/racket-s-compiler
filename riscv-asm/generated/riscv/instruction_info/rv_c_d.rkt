#lang racket/base

(require "struct.rkt")

(define rv_c_d-instructions
  (list
   (instruction-info "c.fld" "rv_c_d" 16 '("rd_p" "rs1_p" "c_uimm8") '("rd_p" "rs1_p" "c_uimm8lo" "c_uimm8hi") '((0 1 0) (13 15 1)) '() "c.fld rd_p, rs1_p, c_uimm8")
   (instruction-info "c.fsd" "rv_c_d" 16 '("rs1_p" "rs2_p" "c_uimm8") '("rs1_p" "rs2_p" "c_uimm8lo" "c_uimm8hi") '((0 1 0) (13 15 5)) '() "c.fsd rs1_p, rs2_p, c_uimm8")
   (instruction-info "c.fldsp" "rv_c_d" 16 '("rd" "c_uimm9sp") '("rd" "c_uimm9sphi" "c_uimm9splo") '((0 1 2) (13 15 1)) '() "c.fldsp rd, c_uimm9sp")
   (instruction-info "c.fsdsp" "rv_c_d" 16 '("c_rs2" "c_uimm9sp_s") '("c_rs2" "c_uimm9sp_s") '((0 1 2) (13 15 5)) '() "c.fsdsp c_rs2, c_uimm9sp_s")))

(provide
 rv_c_d-instructions)
