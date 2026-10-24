#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_zcmp-instructions
  (list
   (instruction-info 'cm.push 'rv_zcmp 16 2 '("c_rlist" "c_spimm") '("c_rlist" "c_spimm") '((0 1 2) (13 15 5) (8 12 24)) '() "cm.push c_rlist, c_spimm")
   (instruction-info 'cm.pop 'rv_zcmp 16 2 '("c_rlist" "c_spimm") '("c_rlist" "c_spimm") '((0 1 2) (13 15 5) (8 12 26)) '() "cm.pop c_rlist, c_spimm")
   (instruction-info 'cm.popretz 'rv_zcmp 16 2 '("c_rlist" "c_spimm") '("c_rlist" "c_spimm") '((0 1 2) (13 15 5) (8 12 28)) '() "cm.popretz c_rlist, c_spimm")
   (instruction-info 'cm.popret 'rv_zcmp 16 2 '("c_rlist" "c_spimm") '("c_rlist" "c_spimm") '((0 1 2) (13 15 5) (8 12 30)) '() "cm.popret c_rlist, c_spimm")
   (instruction-info 'cm.mvsa01 'rv_zcmp 16 2 '("c_sreg1" "c_sreg2") '("c_sreg1" "c_sreg2") '((0 1 2) (13 15 5) (10 12 3) (5 6 1)) '() "cm.mvsa01 c_sreg1, c_sreg2")
   (instruction-info 'cm.mva01s 'rv_zcmp 16 2 '("c_sreg1" "c_sreg2") '("c_sreg1" "c_sreg2") '((0 1 2) (13 15 5) (10 12 3) (5 6 3)) '() "cm.mva01s c_sreg1, c_sreg2")))

(provide
 rv_zcmp-instructions)
