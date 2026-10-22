#lang racket/base

(require "struct.rkt")

(define rv_zvknhb-instructions
  (list
   (instruction-info "vsha2ms.vv" "rv_zvknhb" 32 '("vs2" "vs1" "vd") '("vs2" "vs1" "vd") '((26 31 45) (25 25 1) (12 14 2) (0 6 119)) '() "vsha2ms.vv vs2, vs1, vd")
   (instruction-info "vsha2ch.vv" "rv_zvknhb" 32 '("vs2" "vs1" "vd") '("vs2" "vs1" "vd") '((26 31 46) (25 25 1) (12 14 2) (0 6 119)) '() "vsha2ch.vv vs2, vs1, vd")
   (instruction-info "vsha2cl.vv" "rv_zvknhb" 32 '("vs2" "vs1" "vd") '("vs2" "vs1" "vd") '((26 31 47) (25 25 1) (12 14 2) (0 6 119)) '() "vsha2cl.vv vs2, vs1, vd")))

(provide
 rv_zvknhb-instructions)
