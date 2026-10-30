#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zksed-instructions
  (list
   (instruction-info 'sm4ed 'rv_zksed 32 4 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 24) (12 14 0) (0 6 51)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2") ("bs" "bs")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:bs" "bs")) "sm4ed rd, rs1, rs2, bs")
   (instruction-info 'sm4ks 'rv_zksed 32 4 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 26) (12 14 0) (0 6 51)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2") ("bs" "bs")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:bs" "bs")) "sm4ks rd, rs1, rs2, bs")))

(provide
 rv_zksed-instructions)
