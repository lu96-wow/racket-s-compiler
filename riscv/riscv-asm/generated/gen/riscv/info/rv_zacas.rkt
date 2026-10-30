#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zacas-instructions
  (list
   (instruction-info 'amocas.w 'rv_zacas 32 4 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 1) (12 14 2) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2") ("aq" "aq") ("rl" "rl")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:aq" "aq") ("raw:rl" "rl")) "amocas.w rd, rs1, rs2, aq, rl")
   (instruction-info 'amocas.d 'rv_zacas 32 4 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 1) (12 14 3) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2") ("aq" "aq") ("rl" "rl")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:aq" "aq") ("raw:rl" "rl")) "amocas.d rd, rs1, rs2, aq, rl")))

(provide
 rv_zacas-instructions)
