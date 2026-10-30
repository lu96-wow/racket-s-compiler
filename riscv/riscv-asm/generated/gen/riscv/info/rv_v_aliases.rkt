#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_v_aliases-instructions
  (list
   (instruction-info 'vl1r.v 'rv_v_aliases 32 4 '("rs1" "vd") '("rs1" "vd") '((29 31 0) (28 28 0) (26 27 0) (25 25 1) (20 24 8) (12 14 0) (0 6 7)) '() (instruction-origin 'pseudo 'rv_v 'vl1re8.v) '(("rs1" "rs1") ("vd" "vd")) '(("raw:rs1" "rs1") ("raw:vd" "vd")) "vl1r.v rs1, vd")
   (instruction-info 'vl2r.v 'rv_v_aliases 32 4 '("rs1" "vd") '("rs1" "vd") '((29 31 1) (28 28 0) (26 27 0) (25 25 1) (20 24 8) (12 14 0) (0 6 7)) '() (instruction-origin 'pseudo 'rv_v 'vl2re8.v) '(("rs1" "rs1") ("vd" "vd")) '(("raw:rs1" "rs1") ("raw:vd" "vd")) "vl2r.v rs1, vd")
   (instruction-info 'vl4r.v 'rv_v_aliases 32 4 '("rs1" "vd") '("rs1" "vd") '((29 31 3) (28 28 0) (26 27 0) (25 25 1) (20 24 8) (12 14 0) (0 6 7)) '() (instruction-origin 'pseudo 'rv_v 'vl4re8.v) '(("rs1" "rs1") ("vd" "vd")) '(("raw:rs1" "rs1") ("raw:vd" "vd")) "vl4r.v rs1, vd")
   (instruction-info 'vl8r.v 'rv_v_aliases 32 4 '("rs1" "vd") '("rs1" "vd") '((29 31 7) (28 28 0) (26 27 0) (25 25 1) (20 24 8) (12 14 0) (0 6 7)) '() (instruction-origin 'pseudo 'rv_v 'vl8re8.v) '(("rs1" "rs1") ("vd" "vd")) '(("raw:rs1" "rs1") ("raw:vd" "vd")) "vl8r.v rs1, vd")
   (instruction-info 'vle1.v 'rv_v_aliases 32 4 '("rs1" "vd") '("rs1" "vd") '((28 31 0) (26 27 0) (25 25 1) (20 24 11) (12 14 0) (0 6 7)) '() (instruction-origin 'pseudo 'rv_v 'vlm.v) '(("rs1" "rs1") ("vd" "vd")) '(("raw:rs1" "rs1") ("raw:vd" "vd")) "vle1.v rs1, vd")
   (instruction-info 'vse1.v 'rv_v_aliases 32 4 '("rs1" "vs3") '("rs1" "vs3") '((28 31 0) (26 27 0) (25 25 1) (20 24 11) (12 14 0) (0 6 39)) '() (instruction-origin 'pseudo 'rv_v 'vsm.v) '(("rs1" "rs1") ("vs3" "vs3")) '(("raw:rs1" "rs1") ("raw:vs3" "vs3")) "vse1.v rs1, vs3")
   (instruction-info 'vfredsum.vs 'rv_v_aliases 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 1) (12 14 1) (0 6 87)) '() (instruction-origin 'pseudo 'rv_v 'vfredusum.vs) '(("vm" "vm") ("vs2" "vs2") ("vs1" "vs1") ("vd" "vd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:vs1" "vs1") ("raw:vd" "vd")) "vfredsum.vs vm, vs2, vs1, vd")
   (instruction-info 'vfwredsum.vs 'rv_v_aliases 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 49) (12 14 1) (0 6 87)) '() (instruction-origin 'pseudo 'rv_v 'vfwredusum.vs) '(("vm" "vm") ("vs2" "vs2") ("vs1" "vs1") ("vd" "vd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:vs1" "vs1") ("raw:vd" "vd")) "vfwredsum.vs vm, vs2, vs1, vd")
   (instruction-info 'vpopc.m 'rv_v_aliases 32 4 '("vm" "vs2" "rd") '("vm" "vs2" "rd") '((26 31 16) (15 19 16) (12 14 2) (0 6 87)) '() (instruction-origin 'pseudo 'rv_v 'vcpop.m) '(("vm" "vm") ("vs2" "vs2") ("rd" "rd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:rd" "rd")) "vpopc.m vm, vs2, rd")
   (instruction-info 'vmornot.mm 'rv_v_aliases 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 28) (12 14 2) (0 6 87)) '() (instruction-origin 'pseudo 'rv_v 'vmorn.mm) '(("vm" "vm") ("vs2" "vs2") ("vs1" "vs1") ("vd" "vd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:vs1" "vs1") ("raw:vd" "vd")) "vmornot.mm vm, vs2, vs1, vd")
   (instruction-info 'vmandnot.mm 'rv_v_aliases 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 24) (12 14 2) (0 6 87)) '() (instruction-origin 'pseudo 'rv_v 'vmandn.mm) '(("vm" "vm") ("vs2" "vs2") ("vs1" "vs1") ("vd" "vd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:vs1" "vs1") ("raw:vd" "vd")) "vmandnot.mm vm, vs2, vs1, vd")))

(provide
 rv_v_aliases-instructions)
