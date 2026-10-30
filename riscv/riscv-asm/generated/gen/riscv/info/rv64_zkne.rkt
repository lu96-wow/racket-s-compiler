#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv64_zkne-instructions
  (list
   (instruction-info 'aes64esm 'rv64_zkne 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 27) (12 14 0) (0 6 51)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "aes64esm rd, rs1, rs2")
   (instruction-info 'aes64es 'rv64_zkne 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 25) (12 14 0) (0 6 51)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "aes64es rd, rs1, rs2")
   (instruction-info 'aes64ks1i 'rv64_zkne 32 4 '("rd" "rs1" "rnum") '("rd" "rs1" "rnum") '((30 31 0) (25 29 24) (24 24 1) (12 14 1) (0 6 19)) '() (instruction-origin 'import 'rv64_zknd 'aes64ks1i) '(("rd" "rd") ("rs1" "rs1") ("rnum" "rnum")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rnum" "rnum")) "aes64ks1i rd, rs1, rnum")
   (instruction-info 'aes64ks2 'rv64_zkne 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 31) (12 14 0) (0 6 51)) '() (instruction-origin 'import 'rv64_zknd 'aes64ks2) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "aes64ks2 rd, rs1, rs2")))

(provide
 rv64_zkne-instructions)
