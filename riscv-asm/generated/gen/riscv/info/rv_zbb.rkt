#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zbb-instructions
  (list
   (instruction-info 'andn 'rv_zbb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 7) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "andn rd, rs1, rs2")
   (instruction-info 'orn 'rv_zbb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 6) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "orn rd, rs1, rs2")
   (instruction-info 'xnor 'rv_zbb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 4) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "xnor rd, rs1, rs2")
   (instruction-info 'clz 'rv_zbb 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 1536) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "clz rd, rs1")
   (instruction-info 'ctz 'rv_zbb 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 1537) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "ctz rd, rs1")
   (instruction-info 'cpop 'rv_zbb 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 1538) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "cpop rd, rs1")
   (instruction-info 'max 'rv_zbb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 6) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "max rd, rs1, rs2")
   (instruction-info 'maxu 'rv_zbb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 7) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "maxu rd, rs1, rs2")
   (instruction-info 'min 'rv_zbb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 4) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "min rd, rs1, rs2")
   (instruction-info 'minu 'rv_zbb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 5) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "minu rd, rs1, rs2")
   (instruction-info 'sext.b 'rv_zbb 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 1540) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "sext.b rd, rs1")
   (instruction-info 'sext.h 'rv_zbb 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 1541) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "sext.h rd, rs1")
   (instruction-info 'rol 'rv_zbb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 1) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "rol rd, rs1, rs2")
   (instruction-info 'ror 'rv_zbb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 5) (2 6 12) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "ror rd, rs1, rs2")
   (instruction-info 'orc.b 'rv_zbb 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 647) (12 14 5) (0 6 19)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "orc.b rd, rs1")))

(provide
 rv_zbb-instructions)
