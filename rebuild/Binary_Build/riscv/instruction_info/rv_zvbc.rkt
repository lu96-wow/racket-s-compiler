#lang racket/base

(require "struct.rkt")

(define rv_zvbc-instructions
  (list
   (instruction-info "vclmul.vv" "rv_zvbc" 32 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 12) (12 14 2) (0 6 87)) '() "vclmul.vv vm, vs2, vs1, vd")
   (instruction-info "vclmul.vx" "rv_zvbc" 32 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 12) (12 14 6) (0 6 87)) '() "vclmul.vx vm, vs2, rs1, vd")
   (instruction-info "vclmulh.vv" "rv_zvbc" 32 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 13) (12 14 2) (0 6 87)) '() "vclmulh.vv vm, vs2, vs1, vd")
   (instruction-info "vclmulh.vx" "rv_zvbc" 32 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 13) (12 14 6) (0 6 87)) '() "vclmulh.vx vm, vs2, rs1, vd")))

(provide
 rv_zvbc-instructions)
