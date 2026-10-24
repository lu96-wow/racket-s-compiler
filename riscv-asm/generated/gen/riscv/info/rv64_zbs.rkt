#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv64_zbs-instructions
  (list
   (instruction-info 'bclri 'rv64_zbs 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 18) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("shamtd" "shamtd")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtd" "shamtd")) "bclri rd, rs1, shamtd")
   (instruction-info 'bexti 'rv64_zbs 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 18) (12 14 5) (2 6 4) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("shamtd" "shamtd")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtd" "shamtd")) "bexti rd, rs1, shamtd")
   (instruction-info 'binvi 'rv64_zbs 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 26) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("shamtd" "shamtd")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtd" "shamtd")) "binvi rd, rs1, shamtd")
   (instruction-info 'bseti 'rv64_zbs 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 10) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("shamtd" "shamtd")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtd" "shamtd")) "bseti rd, rs1, shamtd")))

(provide
 rv64_zbs-instructions)
