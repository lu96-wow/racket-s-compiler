#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv64_zba-instructions
  (list
   (instruction-info 'add.uw 'rv64_zba 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 4) (12 14 0) (2 6 14) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "add.uw rd, rs1, rs2")
   (instruction-info 'sh1add.uw 'rv64_zba 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 16) (12 14 2) (2 6 14) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "sh1add.uw rd, rs1, rs2")
   (instruction-info 'sh2add.uw 'rv64_zba 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 16) (12 14 4) (2 6 14) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "sh2add.uw rd, rs1, rs2")
   (instruction-info 'sh3add.uw 'rv64_zba 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 16) (12 14 6) (2 6 14) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "sh3add.uw rd, rs1, rs2")
   (instruction-info 'slli.uw 'rv64_zba 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 2) (12 14 1) (2 6 6) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("shamtd" "shamtd")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtd" "shamtd")) "slli.uw rd, rs1, shamtd")
   (instruction-info 'zext.w 'rv64_zba 32 4 '("rd" "rs1") '("rd" "rs1") '((25 31 4) (20 24 0) (12 14 0) (2 6 14) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_zba 'add.uw) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "zext.w rd, rs1")))

(provide
 rv64_zba-instructions)
