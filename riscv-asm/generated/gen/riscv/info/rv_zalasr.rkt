#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zalasr-instructions
  (list
   (instruction-info 'lb.aq 'rv_zalasr 32 4 '("rd" "rs1" "rl") '("rd" "rs1" "rl") '((26 26 1) (27 31 6) (20 24 0) (12 14 0) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rl" "rl")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rl" "rl")) "lb.aq rd, rs1, rl")
   (instruction-info 'lh.aq 'rv_zalasr 32 4 '("rd" "rs1" "rl") '("rd" "rs1" "rl") '((26 26 1) (27 31 6) (20 24 0) (12 14 1) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rl" "rl")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rl" "rl")) "lh.aq rd, rs1, rl")
   (instruction-info 'lw.aq 'rv_zalasr 32 4 '("rd" "rs1" "rl") '("rd" "rs1" "rl") '((26 26 1) (27 31 6) (20 24 0) (12 14 2) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rl" "rl")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rl" "rl")) "lw.aq rd, rs1, rl")
   (instruction-info 'ld.aq 'rv_zalasr 32 4 '("rd" "rs1" "rl") '("rd" "rs1" "rl") '((26 26 1) (27 31 6) (20 24 0) (12 14 3) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rl" "rl")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rl" "rl")) "ld.aq rd, rs1, rl")
   (instruction-info 'sb.rl 'rv_zalasr 32 4 '("rs1" "rs2" "aq") '("rs1" "rs2" "aq") '((25 25 1) (27 31 7) (12 14 0) (7 11 0) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rs1" "rs1") ("rs2" "rs2") ("aq" "aq")) '(("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:aq" "aq")) "sb.rl rs1, rs2, aq")
   (instruction-info 'sh.rl 'rv_zalasr 32 4 '("rs1" "rs2" "aq") '("rs1" "rs2" "aq") '((25 25 1) (27 31 7) (12 14 1) (7 11 0) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rs1" "rs1") ("rs2" "rs2") ("aq" "aq")) '(("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:aq" "aq")) "sh.rl rs1, rs2, aq")
   (instruction-info 'sw.rl 'rv_zalasr 32 4 '("rs1" "rs2" "aq") '("rs1" "rs2" "aq") '((25 25 1) (27 31 7) (12 14 2) (7 11 0) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rs1" "rs1") ("rs2" "rs2") ("aq" "aq")) '(("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:aq" "aq")) "sw.rl rs1, rs2, aq")
   (instruction-info 'sd.rl 'rv_zalasr 32 4 '("rs1" "rs2" "aq") '("rs1" "rs2" "aq") '((25 25 1) (27 31 7) (12 14 3) (7 11 0) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rs1" "rs1") ("rs2" "rs2") ("aq" "aq")) '(("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:aq" "aq")) "sd.rl rs1, rs2, aq")))

(provide
 rv_zalasr-instructions)
