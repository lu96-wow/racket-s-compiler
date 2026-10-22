#lang racket/base

(require "struct.rkt")

(define rv_zfh-instructions
  (list
   (instruction-info "fmadd.h" "rv_zfh" 32 '("rd" "rs1" "rs2" "rs3" "rm") '("rd" "rs1" "rs2" "rs3" "rm") '((25 26 2) (2 6 16) (0 1 3)) '() "fmadd.h rd, rs1, rs2, rs3, rm")
   (instruction-info "fmsub.h" "rv_zfh" 32 '("rd" "rs1" "rs2" "rs3" "rm") '("rd" "rs1" "rs2" "rs3" "rm") '((25 26 2) (2 6 17) (0 1 3)) '() "fmsub.h rd, rs1, rs2, rs3, rm")
   (instruction-info "fnmsub.h" "rv_zfh" 32 '("rd" "rs1" "rs2" "rs3" "rm") '("rd" "rs1" "rs2" "rs3" "rm") '((25 26 2) (2 6 18) (0 1 3)) '() "fnmsub.h rd, rs1, rs2, rs3, rm")
   (instruction-info "fnmadd.h" "rv_zfh" 32 '("rd" "rs1" "rs2" "rs3" "rm") '("rd" "rs1" "rs2" "rs3" "rm") '((25 26 2) (2 6 19) (0 1 3)) '() "fnmadd.h rd, rs1, rs2, rs3, rm")
   (instruction-info "fadd.h" "rv_zfh" 32 '("rd" "rs1" "rs2" "rm") '("rd" "rs1" "rs2" "rm") '((27 31 0) (25 26 2) (2 6 20) (0 1 3)) '() "fadd.h rd, rs1, rs2, rm")
   (instruction-info "fsub.h" "rv_zfh" 32 '("rd" "rs1" "rs2" "rm") '("rd" "rs1" "rs2" "rm") '((27 31 1) (25 26 2) (2 6 20) (0 1 3)) '() "fsub.h rd, rs1, rs2, rm")
   (instruction-info "fmul.h" "rv_zfh" 32 '("rd" "rs1" "rs2" "rm") '("rd" "rs1" "rs2" "rm") '((27 31 2) (25 26 2) (2 6 20) (0 1 3)) '() "fmul.h rd, rs1, rs2, rm")
   (instruction-info "fdiv.h" "rv_zfh" 32 '("rd" "rs1" "rs2" "rm") '("rd" "rs1" "rs2" "rm") '((27 31 3) (25 26 2) (2 6 20) (0 1 3)) '() "fdiv.h rd, rs1, rs2, rm")
   (instruction-info "fsqrt.h" "rv_zfh" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 0) (27 31 11) (25 26 2) (2 6 20) (0 1 3)) '() "fsqrt.h rd, rs1, rm")
   (instruction-info "fsgnj.h" "rv_zfh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 4) (12 14 0) (25 26 2) (2 6 20) (0 1 3)) '() "fsgnj.h rd, rs1, rs2")
   (instruction-info "fsgnjn.h" "rv_zfh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 4) (12 14 1) (25 26 2) (2 6 20) (0 1 3)) '() "fsgnjn.h rd, rs1, rs2")
   (instruction-info "fsgnjx.h" "rv_zfh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 4) (12 14 2) (25 26 2) (2 6 20) (0 1 3)) '() "fsgnjx.h rd, rs1, rs2")
   (instruction-info "fmin.h" "rv_zfh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 5) (12 14 0) (25 26 2) (2 6 20) (0 1 3)) '() "fmin.h rd, rs1, rs2")
   (instruction-info "fmax.h" "rv_zfh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 5) (12 14 1) (25 26 2) (2 6 20) (0 1 3)) '() "fmax.h rd, rs1, rs2")
   (instruction-info "feq.h" "rv_zfh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 2) (25 26 2) (2 6 20) (0 1 3)) '() "feq.h rd, rs1, rs2")
   (instruction-info "flt.h" "rv_zfh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 1) (25 26 2) (2 6 20) (0 1 3)) '() "flt.h rd, rs1, rs2")
   (instruction-info "fle.h" "rv_zfh" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 0) (25 26 2) (2 6 20) (0 1 3)) '() "fle.h rd, rs1, rs2")
   (instruction-info "fclass.h" "rv_zfh" 32 '("rd" "rs1") '("rd" "rs1") '((20 24 0) (27 31 28) (12 14 1) (25 26 2) (2 6 20) (0 1 3)) '() "fclass.h rd, rs1")
   (instruction-info "fcvt.w.h" "rv_zfh" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 0) (27 31 24) (25 26 2) (2 6 20) (0 1 3)) '() "fcvt.w.h rd, rs1, rm")
   (instruction-info "fcvt.wu.h" "rv_zfh" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 1) (27 31 24) (25 26 2) (2 6 20) (0 1 3)) '() "fcvt.wu.h rd, rs1, rm")
   (instruction-info "fcvt.h.w" "rv_zfh" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 0) (27 31 26) (25 26 2) (2 6 20) (0 1 3)) '() "fcvt.h.w rd, rs1, rm")
   (instruction-info "fcvt.h.wu" "rv_zfh" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 1) (27 31 26) (25 26 2) (2 6 20) (0 1 3)) '() "fcvt.h.wu rd, rs1, rm")
   (instruction-info "fmv.h" "rv_zfh" 32 '("rd" "rs1") '("rd" "rs1") '((27 31 4) (12 14 0) (25 26 2) (2 6 20) (0 1 3)) '(("rs2" "rs1")) "fmv.h rd, rs1")
   (instruction-info "fabs.h" "rv_zfh" 32 '("rd" "rs1") '("rd" "rs1") '((27 31 4) (12 14 2) (25 26 2) (2 6 20) (0 1 3)) '(("rs2" "rs1")) "fabs.h rd, rs1")
   (instruction-info "fneg.h" "rv_zfh" 32 '("rd" "rs1") '("rd" "rs1") '((27 31 4) (12 14 1) (25 26 2) (2 6 20) (0 1 3)) '(("rs2" "rs1")) "fneg.h rd, rs1")))

(provide rv_zfh-instructions)
