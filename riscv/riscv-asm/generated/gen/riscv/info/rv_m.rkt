#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_m-instructions
  (list
   (instruction-info 'mul 'rv_m 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 0) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "mul rd, rs1, rs2")
   (instruction-info 'mulh 'rv_m 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 1) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "mulh rd, rs1, rs2")
   (instruction-info 'mulhsu 'rv_m 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 2) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "mulhsu rd, rs1, rs2")
   (instruction-info 'mulhu 'rv_m 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 3) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "mulhu rd, rs1, rs2")
   (instruction-info 'div 'rv_m 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 4) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "div rd, rs1, rs2")
   (instruction-info 'divu 'rv_m 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 5) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "divu rd, rs1, rs2")
   (instruction-info 'rem 'rv_m 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 6) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "rem rd, rs1, rs2")
   (instruction-info 'remu 'rv_m 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 7) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "remu rd, rs1, rs2")))

(provide
 rv_m-instructions)
