#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_f_zfa-instructions
  (list
   (instruction-info 'fli.s 'rv_f_zfa 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 1) (27 31 30) (12 14 0) (25 26 0) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "fli.s rd, rs1")
   (instruction-info 'fminm.s 'rv_f_zfa 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 5) (12 14 2) (25 26 0) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "fminm.s rd, rs1, rs2")
   (instruction-info 'fmaxm.s 'rv_f_zfa 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 5) (12 14 3) (25 26 0) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "fmaxm.s rd, rs1, rs2")
   (instruction-info 'fround.s 'rv_f_zfa 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 4) (27 31 8) (25 26 0) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rm" "rm")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rm" "rm")) "fround.s rd, rs1, rm")
   (instruction-info 'froundnx.s 'rv_f_zfa 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 5) (27 31 8) (25 26 0) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rm" "rm")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rm" "rm")) "froundnx.s rd, rs1, rm")
   (instruction-info 'fleq.s 'rv_f_zfa 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 4) (25 26 0) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "fleq.s rd, rs1, rs2")
   (instruction-info 'fltq.s 'rv_f_zfa 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 20) (12 14 5) (25 26 0) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "fltq.s rd, rs1, rs2")))

(provide
 rv_f_zfa-instructions)
