#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv64_zk-instructions
  (list
   (instruction-info 'rolw 'rv64_zk 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 1) (2 6 14) (0 1 3)) '() (instruction-origin 'import 'rv64_zbb 'rolw) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "rolw rd, rs1, rs2")
   (instruction-info 'rorw 'rv64_zk 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 5) (2 6 14) (0 1 3)) '() (instruction-origin 'import 'rv64_zbb 'rorw) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "rorw rd, rs1, rs2")
   (instruction-info 'roriw 'rv64_zk 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 48) (12 14 5) (2 6 6) (0 1 3)) '() (instruction-origin 'import 'rv64_zbb 'roriw) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "roriw rd, rs1, shamtw")
   (instruction-info 'rori 'rv64_zk 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 24) (12 14 5) (2 6 4) (0 1 3)) '() (instruction-origin 'import 'rv64_zbb 'rori) '(("rd" "rd") ("rs1" "rs1") ("shamtd" "shamtd")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtd" "shamtd")) "rori rd, rs1, shamtd")
   (instruction-info 'packw 'rv64_zk 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 4) (12 14 4) (2 6 14) (0 1 3)) '() (instruction-origin 'import 'rv64_zbkb 'packw) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "packw rd, rs1, rs2")
   (instruction-info 'aes64esm 'rv64_zk 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 27) (12 14 0) (0 6 51)) '() (instruction-origin 'import 'rv64_zkne 'aes64esm) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "aes64esm rd, rs1, rs2")
   (instruction-info 'aes64es 'rv64_zk 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 25) (12 14 0) (0 6 51)) '() (instruction-origin 'import 'rv64_zkne 'aes64es) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "aes64es rd, rs1, rs2")
   (instruction-info 'aes64ks1i 'rv64_zk 32 4 '("rd" "rs1" "rnum") '("rd" "rs1" "rnum") '((30 31 0) (25 29 24) (24 24 1) (12 14 1) (0 6 19)) '() (instruction-origin 'import 'rv64_zknd 'aes64ks1i) '(("rd" "rd") ("rs1" "rs1") ("rnum" "rnum")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rnum" "rnum")) "aes64ks1i rd, rs1, rnum")
   (instruction-info 'aes64ks2 'rv64_zk 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 31) (12 14 0) (0 6 51)) '() (instruction-origin 'import 'rv64_zknd 'aes64ks2) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "aes64ks2 rd, rs1, rs2")
   (instruction-info 'aes64dsm 'rv64_zk 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 31) (12 14 0) (0 6 51)) '() (instruction-origin 'import 'rv64_zknd 'aes64dsm) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "aes64dsm rd, rs1, rs2")
   (instruction-info 'aes64ds 'rv64_zk 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 29) (12 14 0) (0 6 51)) '() (instruction-origin 'import 'rv64_zknd 'aes64ds) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "aes64ds rd, rs1, rs2")
   (instruction-info 'aes64im 'rv64_zk 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 24) (20 24 0) (12 14 1) (0 6 19)) '() (instruction-origin 'import 'rv64_zknd 'aes64im) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "aes64im rd, rs1")
   (instruction-info 'sha512sum0 'rv64_zk 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 4) (12 14 1) (0 6 19)) '() (instruction-origin 'import 'rv64_zknh 'sha512sum0) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "sha512sum0 rd, rs1")
   (instruction-info 'sha512sum1 'rv64_zk 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 5) (12 14 1) (0 6 19)) '() (instruction-origin 'import 'rv64_zknh 'sha512sum1) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "sha512sum1 rd, rs1")
   (instruction-info 'sha512sig0 'rv64_zk 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 6) (12 14 1) (0 6 19)) '() (instruction-origin 'import 'rv64_zknh 'sha512sig0) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "sha512sig0 rd, rs1")
   (instruction-info 'sha512sig1 'rv64_zk 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 7) (12 14 1) (0 6 19)) '() (instruction-origin 'import 'rv64_zknh 'sha512sig1) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "sha512sig1 rd, rs1")
   (instruction-info 'rev8 'rv64_zk 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 1720) (12 14 5) (0 6 19)) '() (instruction-origin 'pseudo 'rv64_zbb 'rev8) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "rev8 rd, rs1")))

(provide
 rv64_zk-instructions)
