#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zvksed-instructions
  (list
   (instruction-info 'vsm4k.vi 'rv_zvksed 32 4 '("vs2" "zimm5" "vd") '("vs2" "zimm5" "vd") '((26 31 33) (25 25 1) (12 14 2) (0 6 119)) '() (instruction-origin 'standard #f #f) '(("vs2" "vs2") ("zimm5" "zimm5") ("vd" "vd")) '(("raw:vs2" "vs2") ("raw:zimm5" "zimm5") ("raw:vd" "vd")) "vsm4k.vi vs2, zimm5, vd")
   (instruction-info 'vsm4r.vv 'rv_zvksed 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 40) (25 25 1) (15 19 16) (12 14 2) (0 6 119)) '() (instruction-origin 'standard #f #f) '(("vs2" "vs2") ("vd" "vd")) '(("raw:vs2" "vs2") ("raw:vd" "vd")) "vsm4r.vv vs2, vd")
   (instruction-info 'vsm4r.vs 'rv_zvksed 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 16) (12 14 2) (0 6 119)) '() (instruction-origin 'standard #f #f) '(("vs2" "vs2") ("vd" "vd")) '(("raw:vs2" "vs2") ("raw:vd" "vd")) "vsm4r.vs vs2, vd")))

(provide
 rv_zvksed-instructions)
