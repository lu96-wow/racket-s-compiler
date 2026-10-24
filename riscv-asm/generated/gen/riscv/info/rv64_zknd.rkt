#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv64_zknd-instructions
  (list
   (instruction-info 'aes64dsm 'rv64_zknd 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 31) (12 14 0) (0 6 51)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "aes64dsm rd, rs1, rs2")
   (instruction-info 'aes64ds 'rv64_zknd 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 29) (12 14 0) (0 6 51)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "aes64ds rd, rs1, rs2")
   (instruction-info 'aes64ks1i 'rv64_zknd 32 4 '("rd" "rs1" "rnum") '("rd" "rs1" "rnum") '((30 31 0) (25 29 24) (24 24 1) (12 14 1) (0 6 19)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rnum" "rnum")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rnum" "rnum")) "aes64ks1i rd, rs1, rnum")
   (instruction-info 'aes64im 'rv64_zknd 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 24) (20 24 0) (12 14 1) (0 6 19)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "aes64im rd, rs1")
   (instruction-info 'aes64ks2 'rv64_zknd 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 31) (12 14 0) (0 6 51)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "aes64ks2 rd, rs1, rs2")))

(provide
 rv64_zknd-instructions)
