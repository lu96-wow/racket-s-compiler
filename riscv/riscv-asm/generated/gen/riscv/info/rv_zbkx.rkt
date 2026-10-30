#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zbkx-instructions
  (list
   (instruction-info 'xperm4 'rv_zbkx 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 20) (12 14 2) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "xperm4 rd, rs1, rs2")
   (instruction-info 'xperm8 'rv_zbkx 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 20) (12 14 4) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "xperm8 rd, rs1, rs2")))

(provide
 rv_zbkx-instructions)
