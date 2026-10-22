#lang racket/base

(require "struct.rkt")

(define rv_zalasr-instructions
  (list
   (instruction-info "lb.aq" "rv_zalasr" 32 '("rd" "rs1" "rl") '("rd" "rs1" "rl") '((26 26 1) (27 31 6) (20 24 0) (12 14 0) (2 6 11) (0 1 3)) '() "lb.aq rd, rs1, rl")
   (instruction-info "lh.aq" "rv_zalasr" 32 '("rd" "rs1" "rl") '("rd" "rs1" "rl") '((26 26 1) (27 31 6) (20 24 0) (12 14 1) (2 6 11) (0 1 3)) '() "lh.aq rd, rs1, rl")
   (instruction-info "lw.aq" "rv_zalasr" 32 '("rd" "rs1" "rl") '("rd" "rs1" "rl") '((26 26 1) (27 31 6) (20 24 0) (12 14 2) (2 6 11) (0 1 3)) '() "lw.aq rd, rs1, rl")
   (instruction-info "ld.aq" "rv_zalasr" 32 '("rd" "rs1" "rl") '("rd" "rs1" "rl") '((26 26 1) (27 31 6) (20 24 0) (12 14 3) (2 6 11) (0 1 3)) '() "ld.aq rd, rs1, rl")
   (instruction-info "sb.rl" "rv_zalasr" 32 '("rs1" "rs2" "aq") '("rs1" "rs2" "aq") '((25 25 1) (27 31 7) (12 14 0) (7 11 0) (2 6 11) (0 1 3)) '() "sb.rl rs1, rs2, aq")
   (instruction-info "sh.rl" "rv_zalasr" 32 '("rs1" "rs2" "aq") '("rs1" "rs2" "aq") '((25 25 1) (27 31 7) (12 14 1) (7 11 0) (2 6 11) (0 1 3)) '() "sh.rl rs1, rs2, aq")
   (instruction-info "sw.rl" "rv_zalasr" 32 '("rs1" "rs2" "aq") '("rs1" "rs2" "aq") '((25 25 1) (27 31 7) (12 14 2) (7 11 0) (2 6 11) (0 1 3)) '() "sw.rl rs1, rs2, aq")
   (instruction-info "sd.rl" "rv_zalasr" 32 '("rs1" "rs2" "aq") '("rs1" "rs2" "aq") '((25 25 1) (27 31 7) (12 14 3) (7 11 0) (2 6 11) (0 1 3)) '() "sd.rl rs1, rs2, aq")))

(provide
 rv_zalasr-instructions)
