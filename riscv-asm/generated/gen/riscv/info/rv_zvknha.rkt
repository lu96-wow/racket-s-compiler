#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zvknha-instructions
  (list
   (instruction-info 'vsha2ms.vv 'rv_zvknha 32 4 '("vs2" "vs1" "vd") '("vs2" "vs1" "vd") '((26 31 45) (25 25 1) (12 14 2) (0 6 119)) '() (instruction-origin 'standard #f #f) '(("vs2" "vs2") ("vs1" "vs1") ("vd" "vd")) '(("raw:vs2" "vs2") ("raw:vs1" "vs1") ("raw:vd" "vd")) "vsha2ms.vv vs2, vs1, vd")
   (instruction-info 'vsha2ch.vv 'rv_zvknha 32 4 '("vs2" "vs1" "vd") '("vs2" "vs1" "vd") '((26 31 46) (25 25 1) (12 14 2) (0 6 119)) '() (instruction-origin 'standard #f #f) '(("vs2" "vs2") ("vs1" "vs1") ("vd" "vd")) '(("raw:vs2" "vs2") ("raw:vs1" "vs1") ("raw:vd" "vd")) "vsha2ch.vv vs2, vs1, vd")
   (instruction-info 'vsha2cl.vv 'rv_zvknha 32 4 '("vs2" "vs1" "vd") '("vs2" "vs1" "vd") '((26 31 47) (25 25 1) (12 14 2) (0 6 119)) '() (instruction-origin 'standard #f #f) '(("vs2" "vs2") ("vs1" "vs1") ("vd" "vd")) '(("raw:vs2" "vs2") ("raw:vs1" "vs1") ("raw:vd" "vd")) "vsha2cl.vv vs2, vs1, vd")))

(provide
 rv_zvknha-instructions)
