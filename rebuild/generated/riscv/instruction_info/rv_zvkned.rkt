#lang racket/base

(require "struct.rkt")

(define rv_zvkned-instructions
  (list
   (instruction-info "vaesdf.vv" "rv_zvkned" 32 '("vs2" "vd") '("vs2" "vd") '((26 31 40) (25 25 1) (15 19 1) (12 14 2) (0 6 119)) '() "vaesdf.vv vs2, vd")
   (instruction-info "vaesdf.vs" "rv_zvkned" 32 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 1) (12 14 2) (0 6 119)) '() "vaesdf.vs vs2, vd")
   (instruction-info "vaesdm.vv" "rv_zvkned" 32 '("vs2" "vd") '("vs2" "vd") '((26 31 40) (25 25 1) (15 19 0) (12 14 2) (0 6 119)) '() "vaesdm.vv vs2, vd")
   (instruction-info "vaesdm.vs" "rv_zvkned" 32 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 0) (12 14 2) (0 6 119)) '() "vaesdm.vs vs2, vd")
   (instruction-info "vaesef.vv" "rv_zvkned" 32 '("vs2" "vd") '("vs2" "vd") '((26 31 40) (25 25 1) (15 19 3) (12 14 2) (0 6 119)) '() "vaesef.vv vs2, vd")
   (instruction-info "vaesef.vs" "rv_zvkned" 32 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 3) (12 14 2) (0 6 119)) '() "vaesef.vs vs2, vd")
   (instruction-info "vaesem.vv" "rv_zvkned" 32 '("vs2" "vd") '("vs2" "vd") '((26 31 40) (25 25 1) (15 19 2) (12 14 2) (0 6 119)) '() "vaesem.vv vs2, vd")
   (instruction-info "vaesem.vs" "rv_zvkned" 32 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 2) (12 14 2) (0 6 119)) '() "vaesem.vs vs2, vd")
   (instruction-info "vaesz.vs" "rv_zvkned" 32 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 7) (12 14 2) (0 6 119)) '() "vaesz.vs vs2, vd")
   (instruction-info "vaeskf1.vi" "rv_zvkned" 32 '("vs2" "zimm5" "vd") '("vs2" "zimm5" "vd") '((26 31 34) (25 25 1) (12 14 2) (0 6 119)) '() "vaeskf1.vi vs2, zimm5, vd")
   (instruction-info "vaeskf2.vi" "rv_zvkned" 32 '("vs2" "zimm5" "vd") '("vs2" "zimm5" "vd") '((26 31 42) (25 25 1) (12 14 2) (0 6 119)) '() "vaeskf2.vi vs2, zimm5, vd")))

(provide
 rv_zvkned-instructions)
