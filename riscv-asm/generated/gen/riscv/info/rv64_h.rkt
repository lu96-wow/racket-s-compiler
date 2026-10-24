#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv64_h-instructions
  (list
   (instruction-info 'hlv.wu 'rv64_h 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 1) (25 31 52) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "hlv.wu rd, rs1")
   (instruction-info 'hlv.d 'rv64_h 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 0) (25 31 54) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "hlv.d rd, rs1")
   (instruction-info 'hsv.d 'rv64_h 32 4 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 55) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rs1" "rs1") ("rs2" "rs2")) '(("raw:rs1" "rs1") ("raw:rs2" "rs2")) "hsv.d rs1, rs2")))

(provide
 rv64_h-instructions)
