#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zvfbfwma-instructions
  (list
   (instruction-info 'vfwmaccbf16.vv 'rv_zvfbfwma 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 59) (12 14 1) (0 6 87)) '() (instruction-origin 'standard #f #f) '(("vm" "vm") ("vs2" "vs2") ("vs1" "vs1") ("vd" "vd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:vs1" "vs1") ("raw:vd" "vd")) "vfwmaccbf16.vv vm, vs2, vs1, vd")
   (instruction-info 'vfwmaccbf16.vf 'rv_zvfbfwma 32 4 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 59) (12 14 5) (0 6 87)) '() (instruction-origin 'standard #f #f) '(("vm" "vm") ("vs2" "vs2") ("rs1" "rs1") ("vd" "vd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:rs1" "rs1") ("raw:vd" "vd")) "vfwmaccbf16.vf vm, vs2, rs1, vd")))

(provide
 rv_zvfbfwma-instructions)
