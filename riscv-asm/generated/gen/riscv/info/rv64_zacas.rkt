#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv64_zacas-instructions
  (list
   (instruction-info 'amocas.q 'rv64_zacas 32 4 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 1) (12 14 4) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2") ("aq" "aq") ("rl" "rl")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:aq" "aq") ("raw:rl" "rl")) "amocas.q rd, rs1, rs2, aq, rl")))

(provide
 rv64_zacas-instructions)
