#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zabha_zacas-instructions
  (list
   (instruction-info 'amocas.b 'rv_zabha_zacas 32 4 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 1) (12 14 0) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2") ("aq" "aq") ("rl" "rl")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:aq" "aq") ("raw:rl" "rl")) "amocas.b rd, rs1, rs2, aq, rl")
   (instruction-info 'amocas.h 'rv_zabha_zacas 32 4 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 1) (12 14 1) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2") ("aq" "aq") ("rl" "rl")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:aq" "aq") ("raw:rl" "rl")) "amocas.h rd, rs1, rs2, aq, rl")))

(provide
 rv_zabha_zacas-instructions)
