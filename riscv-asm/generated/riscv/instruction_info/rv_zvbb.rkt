#lang racket/base

(require "struct.rkt")

(define rv_zvbb-instructions
  (list
   (instruction-info "vandn.vv" "rv_zvbb" 32 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 1) (12 14 0) (0 6 87)) '() "vandn.vv vm, vs2, vs1, vd")
   (instruction-info "vandn.vx" "rv_zvbb" 32 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 1) (12 14 4) (0 6 87)) '() "vandn.vx vm, vs2, rs1, vd")
   (instruction-info "vbrev.v" "rv_zvbb" 32 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 10) (12 14 2) (0 6 87)) '() "vbrev.v vm, vs2, vd")
   (instruction-info "vbrev8.v" "rv_zvbb" 32 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 8) (12 14 2) (0 6 87)) '() "vbrev8.v vm, vs2, vd")
   (instruction-info "vrev8.v" "rv_zvbb" 32 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 9) (12 14 2) (0 6 87)) '() "vrev8.v vm, vs2, vd")
   (instruction-info "vclz.v" "rv_zvbb" 32 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 12) (12 14 2) (0 6 87)) '() "vclz.v vm, vs2, vd")
   (instruction-info "vctz.v" "rv_zvbb" 32 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 13) (12 14 2) (0 6 87)) '() "vctz.v vm, vs2, vd")
   (instruction-info "vcpop.v" "rv_zvbb" 32 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 14) (12 14 2) (0 6 87)) '() "vcpop.v vm, vs2, vd")
   (instruction-info "vrol.vv" "rv_zvbb" 32 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 21) (12 14 0) (0 6 87)) '() "vrol.vv vm, vs2, vs1, vd")
   (instruction-info "vrol.vx" "rv_zvbb" 32 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 21) (12 14 4) (0 6 87)) '() "vrol.vx vm, vs2, rs1, vd")
   (instruction-info "vror.vv" "rv_zvbb" 32 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 20) (12 14 0) (0 6 87)) '() "vror.vv vm, vs2, vs1, vd")
   (instruction-info "vror.vx" "rv_zvbb" 32 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 20) (12 14 4) (0 6 87)) '() "vror.vx vm, vs2, rs1, vd")
   (instruction-info "vror.vi" "rv_zvbb" 32 '("zimm6" "vm" "vs2" "vd") '("zimm6hi" "vm" "vs2" "zimm6lo" "vd") '((27 31 10) (12 14 3) (0 6 87)) '() "vror.vi zimm6, vm, vs2, vd")
   (instruction-info "vwsll.vv" "rv_zvbb" 32 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 53) (12 14 0) (0 6 87)) '() "vwsll.vv vm, vs2, vs1, vd")
   (instruction-info "vwsll.vx" "rv_zvbb" 32 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 53) (12 14 4) (0 6 87)) '() "vwsll.vx vm, vs2, rs1, vd")
   (instruction-info "vwsll.vi" "rv_zvbb" 32 '("vm" "vs2" "zimm5" "vd") '("vm" "vs2" "zimm5" "vd") '((26 31 53) (12 14 3) (0 6 87)) '() "vwsll.vi vm, vs2, zimm5, vd")))

(provide
 rv_zvbb-instructions)
