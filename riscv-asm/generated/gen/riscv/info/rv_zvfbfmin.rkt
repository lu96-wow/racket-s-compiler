#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zvfbfmin-instructions
  (list
   (instruction-info 'vfncvtbf16.f.f.w 'rv_zvfbfmin 32 4 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 29) (12 14 1) (0 6 87)) '() (instruction-origin 'standard #f #f) '(("vm" "vm") ("vs2" "vs2") ("vd" "vd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:vd" "vd")) "vfncvtbf16.f.f.w vm, vs2, vd")
   (instruction-info 'vfwcvtbf16.f.f.v 'rv_zvfbfmin 32 4 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 13) (12 14 1) (0 6 87)) '() (instruction-origin 'standard #f #f) '(("vm" "vm") ("vs2" "vs2") ("vd" "vd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:vd" "vd")) "vfwcvtbf16.f.f.v vm, vs2, vd")))

(provide
 rv_zvfbfmin-instructions)
