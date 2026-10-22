#lang racket/base

(require "struct.rkt")

(define rv_d_zfa-instructions
  (list
   (instruction-info "fli.d" "rv_d_zfa" 32 '("rd" "rs1") '("rd" "rs1") '((20 24 1) (27 31 30) (12 14 0) (25 26 1) (2 6 20) (0 1 3)) '() "fli.d rd, rs1")
   (instruction-info "fminm.d" "rv_d_zfa" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 5) (12 14 2) (25 26 1) (2 6 20) (0 1 3)) '() "fminm.d rd, rs1, rs2")
   (instruction-info "fmaxm.d" "rv_d_zfa" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 5) (12 14 3) (25 26 1) (2 6 20) (0 1 3)) '() "fmaxm.d rd, rs1, rs2")
   (instruction-info "fround.d" "rv_d_zfa" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 4) (27 31 8) (25 26 1) (2 6 20) (0 1 3)) '() "fround.d rd, rs1, rm")
   (instruction-info "froundnx.d" "rv_d_zfa" 32 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 5) (27 31 8) (25 26 1) (2 6 20) (0 1 3)) '() "froundnx.d rd, rs1, rm")
   (instruction-info "fcvtmod.w.d" "rv_d_zfa" 32 '("rd" "rs1") '("rd" "rs1") '((20 24 8) (27 31 24) (12 14 1) (25 26 1) (2 6 20) (0 1 3)) '() "fcvtmod.w.d rd, rs1")
   (instruction-info "fleq.d" "rv_d_zfa" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 4) (25 26 1) (2 6 20) (0 1 3)) '() "fleq.d rd, rs1, rs2")
   (instruction-info "fltq.d" "rv_d_zfa" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 5) (25 26 1) (2 6 20) (0 1 3)) '() "fltq.d rd, rs1, rs2")))

(provide rv_d_zfa-instructions)
