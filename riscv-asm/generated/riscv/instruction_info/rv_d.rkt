#lang racket/base

(require "struct.rkt")

(define rv_d-instructions
  (list
   (instruction-info "fld" "rv_d" 32 '("rd" "rs1" "imm12") '("rd" "rs1" "imm12") '((12 14 3) (2 6 1) (0 1 3)) '() "fld rd, rs1, imm12")
   (instruction-info "fsd" "rv_d" 32 '("simm12" "rs1" "rs2") '("imm12hi" "rs1" "rs2" "imm12lo") '((12 14 3) (2 6 9) (0 1 3)) '() "fsd simm12, rs1, rs2")
   (instruction-info "fmadd.d" "rv_d" 32 '("rd" "rs1" "rs2" "rs3" "rm") '("rd" "rs1" "rs2" "rs3" "rm") '((25 26 1) (2 6 16) (0 1 3)) '() "fmadd.d rd, rs1, rs2, rs3, rm")
   (instruction-info "fmsub.d" "rv_d" 32 '("rd" "rs1" "rs2" "rs3" "rm") '("rd" "rs1" "rs2" "rs3" "rm") '((25 26 1) (2 6 17) (0 1 3)) '() "fmsub.d rd, rs1, rs2, rs3, rm")
   (instruction-info "fnmsub.d" "rv_d" 32 '("rd" "rs1" "rs2" "rs3" "rm") '("rd" "rs1" "rs2" "rs3" "rm") '((25 26 1) (2 6 18) (0 1 3)) '() "fnmsub.d rd, rs1, rs2, rs3, rm")
   (instruction-info "fnmadd.d" "rv_d" 32 '("rd" "rs1" "rs2" "rs3" "rm") '("rd" "rs1" "rs2" "rs3" "rm") '((25 26 1) (2 6 19) (0 1 3)) '() "fnmadd.d rd, rs1, rs2, rs3, rm")
   (instruction-info "fadd.d" "rv_d" 32 '("rd" "rs1" "rs2" "rm") '("rd" "rs1" "rs2" "rm") '((27 31 0) (25 26 1) (2 6 20) (0 1 3)) '() "fadd.d rd, rs1, rs2, rm")
   (instruction-info "fsub.d" "rv_d" 32 '("rd" "rs1" "rs2" "rm") '("rd" "rs1" "rs2" "rm") '((27 31 1) (25 26 1) (2 6 20) (0 1 3)) '() "fsub.d rd, rs1, rs2, rm")
   (instruction-info "fmul.d" "rv_d" 32 '("rd" "rs1" "rs2" "rm") '("rd" "rs1" "rs2" "rm") '((27 31 2) (25 26 1) (2 6 20) (0 1 3)) '() "fmul.d rd, rs1, rs2, rm")
   (instruction-info "fdiv.d" "rv_d" 32 '("rd" "rs1" "rs2" "rm") '("rd" "rs1" "rs2" "rm") '((27 31 3) (25 26 1) (2 6 20) (0 1 3)) '() "fdiv.d rd, rs1, rs2, rm")
   (instruction-info "fsqrt.d" "rv_d" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 0) (27 31 11) (25 26 1) (2 6 20) (0 1 3)) '() "fsqrt.d rd, rs1, rm")
   (instruction-info "fsgnj.d" "rv_d" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 4) (12 14 0) (25 26 1) (2 6 20) (0 1 3)) '() "fsgnj.d rd, rs1, rs2")
   (instruction-info "fsgnjn.d" "rv_d" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 4) (12 14 1) (25 26 1) (2 6 20) (0 1 3)) '() "fsgnjn.d rd, rs1, rs2")
   (instruction-info "fsgnjx.d" "rv_d" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 4) (12 14 2) (25 26 1) (2 6 20) (0 1 3)) '() "fsgnjx.d rd, rs1, rs2")
   (instruction-info "fmin.d" "rv_d" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 5) (12 14 0) (25 26 1) (2 6 20) (0 1 3)) '() "fmin.d rd, rs1, rs2")
   (instruction-info "fmax.d" "rv_d" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 5) (12 14 1) (25 26 1) (2 6 20) (0 1 3)) '() "fmax.d rd, rs1, rs2")
   (instruction-info "fcvt.s.d" "rv_d" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 1) (27 31 8) (25 26 0) (2 6 20) (0 1 3)) '() "fcvt.s.d rd, rs1, rm")
   (instruction-info "fcvt.d.s" "rv_d" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 0) (27 31 8) (25 26 1) (2 6 20) (0 1 3)) '() "fcvt.d.s rd, rs1, rm")
   (instruction-info "feq.d" "rv_d" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 2) (25 26 1) (2 6 20) (0 1 3)) '() "feq.d rd, rs1, rs2")
   (instruction-info "flt.d" "rv_d" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 1) (25 26 1) (2 6 20) (0 1 3)) '() "flt.d rd, rs1, rs2")
   (instruction-info "fle.d" "rv_d" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 0) (25 26 1) (2 6 20) (0 1 3)) '() "fle.d rd, rs1, rs2")
   (instruction-info "fclass.d" "rv_d" 32 '("rd" "rs1") '("rd" "rs1") '((20 24 0) (27 31 28) (12 14 1) (25 26 1) (2 6 20) (0 1 3)) '() "fclass.d rd, rs1")
   (instruction-info "fcvt.w.d" "rv_d" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 0) (27 31 24) (25 26 1) (2 6 20) (0 1 3)) '() "fcvt.w.d rd, rs1, rm")
   (instruction-info "fcvt.wu.d" "rv_d" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 1) (27 31 24) (25 26 1) (2 6 20) (0 1 3)) '() "fcvt.wu.d rd, rs1, rm")
   (instruction-info "fcvt.d.w" "rv_d" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 0) (27 31 26) (25 26 1) (2 6 20) (0 1 3)) '() "fcvt.d.w rd, rs1, rm")
   (instruction-info "fcvt.d.wu" "rv_d" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 1) (27 31 26) (25 26 1) (2 6 20) (0 1 3)) '() "fcvt.d.wu rd, rs1, rm")
   (instruction-info "fmv.d" "rv_d" 32 '("rd" "rs1") '("rd" "rs1") '((27 31 4) (12 14 0) (25 26 1) (2 6 20) (0 1 3)) '(("rs2" "rs1")) "fmv.d rd, rs1")
   (instruction-info "fabs.d" "rv_d" 32 '("rd" "rs1") '("rd" "rs1") '((27 31 4) (12 14 2) (25 26 1) (2 6 20) (0 1 3)) '(("rs2" "rs1")) "fabs.d rd, rs1")
   (instruction-info "fneg.d" "rv_d" 32 '("rd" "rs1") '("rd" "rs1") '((27 31 4) (12 14 1) (25 26 1) (2 6 20) (0 1 3)) '(("rs2" "rs1")) "fneg.d rd, rs1")))

(provide
 rv_d-instructions)
