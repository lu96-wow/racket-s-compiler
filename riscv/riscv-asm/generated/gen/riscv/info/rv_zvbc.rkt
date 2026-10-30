#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zvbc-instructions
  (list
   (instruction-info 'vclmul.vv 'rv_zvbc 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 12) (12 14 2) (0 6 87)) '() (instruction-origin 'standard #f #f) '(("vm" "vm") ("vs2" "vs2") ("vs1" "vs1") ("vd" "vd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:vs1" "vs1") ("raw:vd" "vd")) "vclmul.vv vm, vs2, vs1, vd")
   (instruction-info 'vclmul.vx 'rv_zvbc 32 4 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 12) (12 14 6) (0 6 87)) '() (instruction-origin 'standard #f #f) '(("vm" "vm") ("vs2" "vs2") ("rs1" "rs1") ("vd" "vd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:rs1" "rs1") ("raw:vd" "vd")) "vclmul.vx vm, vs2, rs1, vd")
   (instruction-info 'vclmulh.vv 'rv_zvbc 32 4 '("vm" "vs2" "vs1" "vd") '("vm" "vs2" "vs1" "vd") '((26 31 13) (12 14 2) (0 6 87)) '() (instruction-origin 'standard #f #f) '(("vm" "vm") ("vs2" "vs2") ("vs1" "vs1") ("vd" "vd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:vs1" "vs1") ("raw:vd" "vd")) "vclmulh.vv vm, vs2, vs1, vd")
   (instruction-info 'vclmulh.vx 'rv_zvbc 32 4 '("vm" "vs2" "rs1" "vd") '("vm" "vs2" "rs1" "vd") '((26 31 13) (12 14 6) (0 6 87)) '() (instruction-origin 'standard #f #f) '(("vm" "vm") ("vs2" "vs2") ("rs1" "rs1") ("vd" "vd")) '(("raw:vm" "vm") ("raw:vs2" "vs2") ("raw:rs1" "rs1") ("raw:vd" "vd")) "vclmulh.vx vm, vs2, rs1, vd")))

(provide
 rv_zvbc-instructions)
