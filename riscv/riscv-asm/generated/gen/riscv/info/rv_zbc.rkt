#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zbc-instructions
  (list
   (instruction-info 'clmul 'rv_zbc 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 1) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "clmul rd, rs1, rs2")
   (instruction-info 'clmulr 'rv_zbc 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 2) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "clmulr rd, rs1, rs2")
   (instruction-info 'clmulh 'rv_zbc 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 3) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "clmulh rd, rs1, rs2")))

(provide
 rv_zbc-instructions)
