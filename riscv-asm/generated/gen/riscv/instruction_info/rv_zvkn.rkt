#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_zvkn-instructions
  (list
   (instruction-info 'vandn.vv 'rv_zvkn 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 1) (12 14 0) (0 6 87)) '() "vandn.vv vm, vs2, vs1, vd")
   (instruction-info 'vandn.vx 'rv_zvkn 32 4 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 1) (12 14 4) (0 6 87)) '() "vandn.vx vm, vs2, rs1, vd")
   (instruction-info 'vbrev8.v 'rv_zvkn 32 4 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 8) (12 14 2) (0 6 87)) '() "vbrev8.v vm, vs2, vd")
   (instruction-info 'vrev8.v 'rv_zvkn 32 4 '("vm" "vs2" "vd") '("vm" "vs2" "vd") '((26 31 18) (15 19 9) (12 14 2) (0 6 87)) '() "vrev8.v vm, vs2, vd")
   (instruction-info 'vrol.vv 'rv_zvkn 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 21) (12 14 0) (0 6 87)) '() "vrol.vv vm, vs2, vs1, vd")
   (instruction-info 'vrol.vx 'rv_zvkn 32 4 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 21) (12 14 4) (0 6 87)) '() "vrol.vx vm, vs2, rs1, vd")
   (instruction-info 'vror.vv 'rv_zvkn 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 20) (12 14 0) (0 6 87)) '() "vror.vv vm, vs2, vs1, vd")
   (instruction-info 'vror.vx 'rv_zvkn 32 4 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 20) (12 14 4) (0 6 87)) '() "vror.vx vm, vs2, rs1, vd")
   (instruction-info 'vror.vi 'rv_zvkn 32 4 '("zimm6" "vm" "vs2" "vd") '("zimm6hi" "vm" "vs2" "zimm6lo" "vd") '((27 31 10) (12 14 3) (0 6 87)) '() "vror.vi zimm6, vm, vs2, vd")
   (instruction-info 'vaesef.vs 'rv_zvkn 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 3) (12 14 2) (0 6 119)) '() "vaesef.vs vs2, vd")
   (instruction-info 'vaesef.vv 'rv_zvkn 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 40) (25 25 1) (15 19 3) (12 14 2) (0 6 119)) '() "vaesef.vv vs2, vd")
   (instruction-info 'vaesem.vs 'rv_zvkn 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 2) (12 14 2) (0 6 119)) '() "vaesem.vs vs2, vd")
   (instruction-info 'vaesem.vv 'rv_zvkn 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 40) (25 25 1) (15 19 2) (12 14 2) (0 6 119)) '() "vaesem.vv vs2, vd")
   (instruction-info 'vaesdf.vs 'rv_zvkn 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 1) (12 14 2) (0 6 119)) '() "vaesdf.vs vs2, vd")
   (instruction-info 'vaesdf.vv 'rv_zvkn 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 40) (25 25 1) (15 19 1) (12 14 2) (0 6 119)) '() "vaesdf.vv vs2, vd")
   (instruction-info 'vaesdm.vs 'rv_zvkn 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 0) (12 14 2) (0 6 119)) '() "vaesdm.vs vs2, vd")
   (instruction-info 'vaesdm.vv 'rv_zvkn 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 40) (25 25 1) (15 19 0) (12 14 2) (0 6 119)) '() "vaesdm.vv vs2, vd")
   (instruction-info 'vaeskf1.vi 'rv_zvkn 32 4 '("vs2" "zimm5" "vd") '("vs2" "zimm5" "vd") '((26 31 34) (25 25 1) (12 14 2) (0 6 119)) '() "vaeskf1.vi vs2, zimm5, vd")
   (instruction-info 'vaeskf2.vi 'rv_zvkn 32 4 '("vs2" "zimm5" "vd") '("vs2" "zimm5" "vd") '((26 31 42) (25 25 1) (12 14 2) (0 6 119)) '() "vaeskf2.vi vs2, zimm5, vd")
   (instruction-info 'vaesz.vs 'rv_zvkn 32 4 '("vs2" "vd") '("vs2" "vd") '((26 31 41) (25 25 1) (15 19 7) (12 14 2) (0 6 119)) '() "vaesz.vs vs2, vd")
   (instruction-info 'vsha2ms.vv 'rv_zvkn 32 4 '("vs2" "vs1" "vd") '("vs2" "vs1" "vd") '((26 31 45) (25 25 1) (12 14 2) (0 6 119)) '() "vsha2ms.vv vs2, vs1, vd")
   (instruction-info 'vsha2ch.vv 'rv_zvkn 32 4 '("vs2" "vs1" "vd") '("vs2" "vs1" "vd") '((26 31 46) (25 25 1) (12 14 2) (0 6 119)) '() "vsha2ch.vv vs2, vs1, vd")
   (instruction-info 'vsha2cl.vv 'rv_zvkn 32 4 '("vs2" "vs1" "vd") '("vs2" "vs1" "vd") '((26 31 47) (25 25 1) (12 14 2) (0 6 119)) '() "vsha2cl.vv vs2, vs1, vd")))

(provide
 rv_zvkn-instructions)
