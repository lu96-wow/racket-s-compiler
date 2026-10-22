#lang racket/base

(require "struct.rkt")

(define rv64_zkne-instructions
  (list
   (instruction-info "aes64esm" "rv64_zkne" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 27) (12 14 0) (0 6 51)) '() "aes64esm rd, rs1, rs2")
   (instruction-info "aes64es" "rv64_zkne" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 0) (25 29 25) (12 14 0) (0 6 51)) '() "aes64es rd, rs1, rs2")
   (instruction-info "aes64ks1i" "rv64_zkne" 32 '("rd" "rs1" "rnum") '("rd" "rs1" "rnum") '((30 31 0) (25 29 24) (24 24 1) (12 14 1) (0 6 19)) '() "aes64ks1i rd, rs1, rnum")
   (instruction-info "aes64ks2" "rv64_zkne" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 31) (12 14 0) (0 6 51)) '() "aes64ks2 rd, rs1, rs2")))

(provide
 rv64_zkne-instructions)
