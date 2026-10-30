#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zvksh-instructions
  (list
   (instruction-info 'vsm3c.vi 'rv_zvksh 32 4 '("vs2" "zimm5" "vd") '("vs2" "zimm5" "vd") '((26 31 43) (25 25 1) (12 14 2) (0 6 119)) '() (instruction-origin 'standard #f #f) '(("vs2" "vs2") ("zimm5" "zimm5") ("vd" "vd")) '(("raw:vs2" "vs2") ("raw:zimm5" "zimm5") ("raw:vd" "vd")) "vsm3c.vi vs2, zimm5, vd")
   (instruction-info 'vsm3me.vv 'rv_zvksh 32 4 '("vs2" "vs1" "vd") '("vs2" "vs1" "vd") '((26 31 32) (25 25 1) (12 14 2) (0 6 119)) '() (instruction-origin 'standard #f #f) '(("vs2" "vs2") ("vs1" "vs1") ("vd" "vd")) '(("raw:vs2" "vs2") ("raw:vs1" "vs1") ("raw:vd" "vd")) "vsm3me.vv vs2, vs1, vd")))

(provide
 rv_zvksh-instructions)
