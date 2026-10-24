#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv64_zknh-instructions
  (list
   (instruction-info 'sha512sum0 'rv64_zknh 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 4) (12 14 1) (0 6 19)) '() "sha512sum0 rd, rs1")
   (instruction-info 'sha512sum1 'rv64_zknh 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 5) (12 14 1) (0 6 19)) '() "sha512sum1 rd, rs1")
   (instruction-info 'sha512sig0 'rv64_zknh 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 6) (12 14 1) (0 6 19)) '() "sha512sig0 rd, rs1")
   (instruction-info 'sha512sig1 'rv64_zknh 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 7) (12 14 1) (0 6 19)) '() "sha512sig1 rd, rs1")))

(provide
 rv64_zknh-instructions)
