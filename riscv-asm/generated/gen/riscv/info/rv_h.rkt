#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_h-instructions
  (list
   (instruction-info 'hfence.vvma 'rv_h 32 4 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 17) (12 14 0) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rs1" "rs1") ("rs2" "rs2")) '(("raw:rs1" "rs1") ("raw:rs2" "rs2")) "hfence.vvma rs1, rs2")
   (instruction-info 'hfence.gvma 'rv_h 32 4 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 49) (12 14 0) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rs1" "rs1") ("rs2" "rs2")) '(("raw:rs1" "rs1") ("raw:rs2" "rs2")) "hfence.gvma rs1, rs2")
   (instruction-info 'hlv.b 'rv_h 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 0) (25 31 48) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "hlv.b rd, rs1")
   (instruction-info 'hlv.bu 'rv_h 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 1) (25 31 48) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "hlv.bu rd, rs1")
   (instruction-info 'hlv.h 'rv_h 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 0) (25 31 50) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "hlv.h rd, rs1")
   (instruction-info 'hlv.hu 'rv_h 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 1) (25 31 50) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "hlv.hu rd, rs1")
   (instruction-info 'hlvx.hu 'rv_h 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 3) (25 31 50) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "hlvx.hu rd, rs1")
   (instruction-info 'hlv.w 'rv_h 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 0) (25 31 52) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "hlv.w rd, rs1")
   (instruction-info 'hlvx.wu 'rv_h 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 3) (25 31 52) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "hlvx.wu rd, rs1")
   (instruction-info 'hsv.b 'rv_h 32 4 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 49) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rs1" "rs1") ("rs2" "rs2")) '(("raw:rs1" "rs1") ("raw:rs2" "rs2")) "hsv.b rs1, rs2")
   (instruction-info 'hsv.h 'rv_h 32 4 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 51) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rs1" "rs1") ("rs2" "rs2")) '(("raw:rs1" "rs1") ("raw:rs2" "rs2")) "hsv.h rs1, rs2")
   (instruction-info 'hsv.w 'rv_h 32 4 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 53) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rs1" "rs1") ("rs2" "rs2")) '(("raw:rs1" "rs1") ("raw:rs2" "rs2")) "hsv.w rs1, rs2")))

(provide
 rv_h-instructions)
