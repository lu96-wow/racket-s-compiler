#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv64_d-instructions
  (list
   (instruction-info 'fcvt.l.d 'rv64_d 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 2) (27 31 24) (25 26 1) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rm" "rm")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rm" "rm")) "fcvt.l.d rd, rs1, rm")
   (instruction-info 'fcvt.lu.d 'rv64_d 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 3) (27 31 24) (25 26 1) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rm" "rm")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rm" "rm")) "fcvt.lu.d rd, rs1, rm")
   (instruction-info 'fmv.x.d 'rv64_d 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 0) (27 31 28) (12 14 0) (25 26 1) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "fmv.x.d rd, rs1")
   (instruction-info 'fcvt.d.l 'rv64_d 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 2) (27 31 26) (25 26 1) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rm" "rm")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rm" "rm")) "fcvt.d.l rd, rs1, rm")
   (instruction-info 'fcvt.d.lu 'rv64_d 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 3) (27 31 26) (25 26 1) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rm" "rm")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rm" "rm")) "fcvt.d.lu rd, rs1, rm")
   (instruction-info 'fmv.d.x 'rv64_d 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 0) (27 31 30) (12 14 0) (25 26 1) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "fmv.d.x rd, rs1")))

(provide
 rv64_d-instructions)
