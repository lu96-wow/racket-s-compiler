#lang racket/base

(require "struct.rkt")

(define rv32_zk-instructions
  (list
   (instruction-info "aes32esmi" "rv32_zk" 32 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 19) (12 14 0) (0 6 51)) '() "aes32esmi rd, rs1, rs2, bs")
   (instruction-info "aes32esi" "rv32_zk" 32 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 17) (12 14 0) (0 6 51)) '() "aes32esi rd, rs1, rs2, bs")
   (instruction-info "aes32dsmi" "rv32_zk" 32 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 23) (12 14 0) (0 6 51)) '() "aes32dsmi rd, rs1, rs2, bs")
   (instruction-info "aes32dsi" "rv32_zk" 32 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 21) (12 14 0) (0 6 51)) '() "aes32dsi rd, rs1, rs2, bs")
   (instruction-info "sha512sum0r" "rv32_zk" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 8) (12 14 0) (0 6 51)) '() "sha512sum0r rd, rs1, rs2")
   (instruction-info "sha512sum1r" "rv32_zk" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 9) (12 14 0) (0 6 51)) '() "sha512sum1r rd, rs1, rs2")
   (instruction-info "sha512sig0l" "rv32_zk" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 10) (12 14 0) (0 6 51)) '() "sha512sig0l rd, rs1, rs2")
   (instruction-info "sha512sig0h" "rv32_zk" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 14) (12 14 0) (0 6 51)) '() "sha512sig0h rd, rs1, rs2")
   (instruction-info "sha512sig1l" "rv32_zk" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 11) (12 14 0) (0 6 51)) '() "sha512sig1l rd, rs1, rs2")
   (instruction-info "sha512sig1h" "rv32_zk" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((30 31 1) (25 29 15) (12 14 0) (0 6 51)) '() "sha512sig1h rd, rs1, rs2")
   (instruction-info "zip" "rv32_zk" 32 '("rd" "rs1") '("rd" "rs1") '((25 31 4) (20 24 15) (12 14 1) (2 6 4) (0 1 3)) '() "zip rd, rs1")
   (instruction-info "unzip" "rv32_zk" 32 '("rd" "rs1") '("rd" "rs1") '((25 31 4) (20 24 15) (12 14 5) (2 6 4) (0 1 3)) '() "unzip rd, rs1")
   (instruction-info "rori.rv32" "rv32_zk" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 48) (12 14 5) (2 6 4) (0 1 3)) '() "rori.rv32 rd, rs1, shamtw")
   (instruction-info "rev8.rv32" "rv32_zk" 32 '("rd" "rs1") '("rd" "rs1") '((20 31 1688) (12 14 5) (0 6 19)) '() "rev8.rv32 rd, rs1")))

(provide rv32_zk-instructions)
