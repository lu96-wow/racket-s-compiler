#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_zvksed-instructions
  (list
   (instruction-info 'vsm4k.vi 'rv_zvksed 32 4 '("vs2" "zimm5" "vd") '("vs2" "zimm5" "vd") '((26 31 33) (25 25 1) (12 14 2) (0 6 119)) '() "vsm4k.vi vs2, zimm5, vd")
   (instruction-info 'vsm4r.vv 'rv_zvksed 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 40) (25 25 1) (15 19 16) (12 14 2) (0 6 119)) '() "vsm4r.vv vs2, vd")
   (instruction-info 'vsm4r.vs 'rv_zvksed 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 16) (12 14 2) (0 6 119)) '() "vsm4r.vs vs2, vd")))

(provide
 rv_zvksed-instructions)
