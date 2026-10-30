#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zicond-instructions
  (list
   (instruction-info 'czero.eqz 'rv_zicond 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 7) (12 14 5) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "czero.eqz rd, rs1, rs2")
   (instruction-info 'czero.nez 'rv_zicond 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 7) (12 14 7) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "czero.nez rd, rs1, rs2")))

(provide
 rv_zicond-instructions)
