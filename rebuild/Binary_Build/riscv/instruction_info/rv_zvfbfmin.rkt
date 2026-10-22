#lang racket/base

(require "struct.rkt")

(define rv_zvfbfmin-instructions
  (list
   (instruction-info "vfncvtbf16.f.f.w" "rv_zvfbfmin" 32 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 29) (12 14 1) (0 6 87)) '() "vfncvtbf16.f.f.w vm, vs2, vd")
   (instruction-info "vfwcvtbf16.f.f.v" "rv_zvfbfmin" 32 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 13) (12 14 1) (0 6 87)) '() "vfwcvtbf16.f.f.v vm, vs2, vd")))

(provide rv_zvfbfmin-instructions)
