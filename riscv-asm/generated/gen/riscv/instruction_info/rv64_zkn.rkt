#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv64_zkn-instructions
  (list
   (instruction-info 'rolw 'rv64_zkn 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 1) (2 6 14) (0 1 3)) '() "rolw rd, rs1, rs2")
   (instruction-info 'rorw 'rv64_zkn 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 5) (2 6 14) (0 1 3)) '() "rorw rd, rs1, rs2")
   (instruction-info 'roriw 'rv64_zkn 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 48) (12 14 5) (2 6 6) (0 1 3)) '() "roriw rd, rs1, shamtw")
   (instruction-info 'rori 'rv64_zkn 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 24) (12 14 5) (2 6 4) (0 1 3)) '() "rori rd, rs1, shamtd")
   (instruction-info 'packw 'rv64_zkn 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 4) (12 14 4) (2 6 14) (0 1 3)) '() "packw rd, rs1, rs2")
   (instruction-info 'aes64esm 'rv64_zkn 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 27) (12 14 0) (0 6 51)) '() "aes64esm rd, rs1, rs2")
   (instruction-info 'aes64es 'rv64_zkn 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 25) (12 14 0) (0 6 51)) '() "aes64es rd, rs1, rs2")
   (instruction-info 'aes64ks1i 'rv64_zkn 32 4 '("rd" "rs1" "rnum") '("rd" "rs1" "rnum") '((30 31 0) (25 29 24) (24 24 1) (12 14 1) (0 6 19)) '() "aes64ks1i rd, rs1, rnum")
   (instruction-info 'aes64ks2 'rv64_zkn 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 31) (12 14 0) (0 6 51)) '() "aes64ks2 rd, rs1, rs2")
   (instruction-info 'aes64dsm 'rv64_zkn 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 31) (12 14 0) (0 6 51)) '() "aes64dsm rd, rs1, rs2")
   (instruction-info 'aes64ds 'rv64_zkn 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 29) (12 14 0) (0 6 51)) '() "aes64ds rd, rs1, rs2")
   (instruction-info 'aes64im 'rv64_zkn 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 24) (20 24 0) (12 14 1) (0 6 19)) '() "aes64im rd, rs1")
   (instruction-info 'sha512sum0 'rv64_zkn 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 4) (12 14 1) (0 6 19)) '() "sha512sum0 rd, rs1")
   (instruction-info 'sha512sum1 'rv64_zkn 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 5) (12 14 1) (0 6 19)) '() "sha512sum1 rd, rs1")
   (instruction-info 'sha512sig0 'rv64_zkn 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 6) (12 14 1) (0 6 19)) '() "sha512sig0 rd, rs1")
   (instruction-info 'sha512sig1 'rv64_zkn 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 7) (12 14 1) (0 6 19)) '() "sha512sig1 rd, rs1")
   (instruction-info 'rev8 'rv64_zkn 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 1720) (12 14 5) (0 6 19)) '() "rev8 rd, rs1")))

(provide
 rv64_zkn-instructions)
