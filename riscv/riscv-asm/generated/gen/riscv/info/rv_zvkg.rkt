#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zvkg-instructions
  (list
   (instruction-info 'vgmul.vv 'rv_zvkg 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 40) (25 25 1) (15 19 17) (12 14 2) (0 6 119)) '() (instruction-origin 'standard #f #f) '(("vs2" "vs2") ("vd" "vd")) '(("raw:vs2" "vs2") ("raw:vd" "vd")) "vgmul.vv vs2, vd")
   (instruction-info 'vghsh.vv 'rv_zvkg 32 4 '("vs2" "vs1" "vd") '("vs2" "vs1" "vd") '((26 31 44) (25 25 1) (12 14 2) (0 6 119)) '() (instruction-origin 'standard #f #f) '(("vs2" "vs2") ("vs1" "vs1") ("vd" "vd")) '(("raw:vs2" "vs2") ("raw:vs1" "vs1") ("raw:vd" "vd")) "vghsh.vv vs2, vs1, vd")))

(provide
 rv_zvkg-instructions)
