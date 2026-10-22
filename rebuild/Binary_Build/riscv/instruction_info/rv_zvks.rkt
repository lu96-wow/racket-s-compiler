#lang racket/base

(require "struct.rkt")

(define rv_zvks-instructions
  (list
   (instruction-info "vandn.vv" "rv_zvks" 32 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 1) (12 14 0) (0 6 87)) '() "vandn.vv vm, vs2, vs1, vd")
   (instruction-info "vandn.vx" "rv_zvks" 32 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 1) (12 14 4) (0 6 87)) '() "vandn.vx vm, vs2, rs1, vd")
   (instruction-info "vbrev8.v" "rv_zvks" 32 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 8) (12 14 2) (0 6 87)) '() "vbrev8.v vm, vs2, vd")
   (instruction-info "vrev8.v" "rv_zvks" 32 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 9) (12 14 2) (0 6 87)) '() "vrev8.v vm, vs2, vd")
   (instruction-info "vrol.vv" "rv_zvks" 32 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 21) (12 14 0) (0 6 87)) '() "vrol.vv vm, vs2, vs1, vd")
   (instruction-info "vrol.vx" "rv_zvks" 32 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 21) (12 14 4) (0 6 87)) '() "vrol.vx vm, vs2, rs1, vd")
   (instruction-info "vror.vv" "rv_zvks" 32 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 20) (12 14 0) (0 6 87)) '() "vror.vv vm, vs2, vs1, vd")
   (instruction-info "vror.vx" "rv_zvks" 32 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 20) (12 14 4) (0 6 87)) '() "vror.vx vm, vs2, rs1, vd")
   (instruction-info "vror.vi" "rv_zvks" 32 '("zimm6" "vm" "vs2" "vd") '("zimm6hi" "vm" "vs2" "zimm6lo" "vd") '((27 31 10) (12 14 3) (0 6 87)) '() "vror.vi zimm6, vm, vs2, vd")
   (instruction-info "vsm4k.vi" "rv_zvks" 32 '("vs2" "zimm5" "vd") '("vs2" "zimm5" "vd") '((26 31 33) (25 25 1) (12 14 2) (0 6 119)) '() "vsm4k.vi vs2, zimm5, vd")
   (instruction-info "vsm4r.vv" "rv_zvks" 32 '("vs2" "vd") '("vs2" "vd") '((26 31 40) (25 25 1) (15 19 16) (12 14 2) (0 6 119)) '() "vsm4r.vv vs2, vd")
   (instruction-info "vsm4r.vs" "rv_zvks" 32 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 16) (12 14 2) (0 6 119)) '() "vsm4r.vs vs2, vd")
   (instruction-info "vsm3c.vi" "rv_zvks" 32 '("vs2" "zimm5" "vd") '("vs2" "zimm5" "vd") '((26 31 43) (25 25 1) (12 14 2) (0 6 119)) '() "vsm3c.vi vs2, zimm5, vd")
   (instruction-info "vsm3me.vv" "rv_zvks" 32 '("vs2" "vs1" "vd") '("vs2" "vs1" "vd") '((26 31 32) (25 25 1) (12 14 2) (0 6 119)) '() "vsm3me.vv vs2, vs1, vd")))

(provide rv_zvks-instructions)
