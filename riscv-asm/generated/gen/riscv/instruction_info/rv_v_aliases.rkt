#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_v_aliases-instructions
  (list
   (instruction-info 'vl1r.v 'rv_v_aliases 32 4 '("rs1" "vd") '("rs1" "vd") '((29 31 0) (28 28 0) (26 27 0) (25 25 1) (20 24 8) (12 14 0) (0 6 7)) '() "vl1r.v rs1, vd")
   (instruction-info 'vl2r.v 'rv_v_aliases 32 4 '("rs1" "vd") '("rs1" "vd") '((29 31 1) (28 28 0) (26 27 0) (25 25 1) (20 24 8) (12 14 0) (0 6 7)) '() "vl2r.v rs1, vd")
   (instruction-info 'vl4r.v 'rv_v_aliases 32 4 '("rs1" "vd") '("rs1" "vd") '((29 31 3) (28 28 0) (26 27 0) (25 25 1) (20 24 8) (12 14 0) (0 6 7)) '() "vl4r.v rs1, vd")
   (instruction-info 'vl8r.v 'rv_v_aliases 32 4 '("rs1" "vd") '("rs1" "vd") '((29 31 7) (28 28 0) (26 27 0) (25 25 1) (20 24 8) (12 14 0) (0 6 7)) '() "vl8r.v rs1, vd")
   (instruction-info 'vle1.v 'rv_v_aliases 32 4 '("rs1" "vd") '("rs1" "vd") '((28 31 0) (26 27 0) (25 25 1) (20 24 11) (12 14 0) (0 6 7)) '() "vle1.v rs1, vd")
   (instruction-info 'vse1.v 'rv_v_aliases 32 4 '("rs1" "vs3") '("rs1" "vs3") '((28 31 0) (26 27 0) (25 25 1) (20 24 11) (12 14 0) (0 6 39)) '() "vse1.v rs1, vs3")
   (instruction-info 'vfredsum.vs 'rv_v_aliases 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 1) (12 14 1) (0 6 87)) '() "vfredsum.vs vm, vs2, vs1, vd")
   (instruction-info 'vfwredsum.vs 'rv_v_aliases 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 49) (12 14 1) (0 6 87)) '() "vfwredsum.vs vm, vs2, vs1, vd")
   (instruction-info 'vpopc.m 'rv_v_aliases 32 4 '("vm" "vs2" "rd") '("vm" "vs2" "rd") '((26 31 16) (15 19 16) (12 14 2) (0 6 87)) '() "vpopc.m vm, vs2, rd")
   (instruction-info 'vmornot.mm 'rv_v_aliases 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 28) (12 14 2) (0 6 87)) '() "vmornot.mm vm, vs2, vs1, vd")
   (instruction-info 'vmandnot.mm 'rv_v_aliases 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 24) (12 14 2) (0 6 87)) '() "vmandnot.mm vm, vs2, vs1, vd")))

(provide
 rv_v_aliases-instructions)
