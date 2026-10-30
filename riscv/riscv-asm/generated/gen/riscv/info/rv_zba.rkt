#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zba-instructions
  (list
   (instruction-info 'sh1add 'rv_zba 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 16) (12 14 2) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "sh1add rd, rs1, rs2")
   (instruction-info 'sh2add 'rv_zba 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 16) (12 14 4) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "sh2add rd, rs1, rs2")
   (instruction-info 'sh3add 'rv_zba 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 16) (12 14 6) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "sh3add rd, rs1, rs2")))

(provide
 rv_zba-instructions)
