#lang racket/base

(require "struct.rkt")

(define rv64_i-instructions
  (list
   (instruction-info "lwu" "rv64_i" 32 '("rd" "rs1" "imm12") '("rd" "rs1" "imm12") '((12 14 6) (2 6 0) (0 1 3)) '() "lwu rd, rs1, imm12")
   (instruction-info "ld" "rv64_i" 32 '("rd" "rs1" "imm12") '("rd" "rs1" "imm12") '((12 14 3) (2 6 0) (0 1 3)) '() "ld rd, rs1, imm12")
   (instruction-info "sd" "rv64_i" 32 '("simm12" "rs1" "rs2") '("imm12hi" "rs1" "rs2" "imm12lo") '((12 14 3) (2 6 8) (0 1 3)) '() "sd simm12, rs1, rs2")
   (instruction-info "slli" "rv64_i" 32 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 0) (12 14 1) (2 6 4) (0 1 3)) '() "slli rd, rs1, shamtd")
   (instruction-info "srli" "rv64_i" 32 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 0) (12 14 5) (2 6 4) (0 1 3)) '() "srli rd, rs1, shamtd")
   (instruction-info "srai" "rv64_i" 32 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 16) (12 14 5) (2 6 4) (0 1 3)) '() "srai rd, rs1, shamtd")
   (instruction-info "addiw" "rv64_i" 32 '("rd" "rs1" "imm12") '("rd" "rs1" "imm12") '((12 14 0) (2 6 6) (0 1 3)) '() "addiw rd, rs1, imm12")
   (instruction-info "slliw" "rv64_i" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 0) (12 14 1) (2 6 6) (0 1 3)) '() "slliw rd, rs1, shamtw")
   (instruction-info "srliw" "rv64_i" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 0) (12 14 5) (2 6 6) (0 1 3)) '() "srliw rd, rs1, shamtw")
   (instruction-info "sraiw" "rv64_i" 32 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 32) (12 14 5) (2 6 6) (0 1 3)) '() "sraiw rd, rs1, shamtw")
   (instruction-info "addw" "rv64_i" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 0) (12 14 0) (2 6 14) (0 1 3)) '() "addw rd, rs1, rs2")
   (instruction-info "subw" "rv64_i" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 0) (2 6 14) (0 1 3)) '() "subw rd, rs1, rs2")
   (instruction-info "sllw" "rv64_i" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 0) (12 14 1) (2 6 14) (0 1 3)) '() "sllw rd, rs1, rs2")
   (instruction-info "srlw" "rv64_i" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 0) (12 14 5) (2 6 14) (0 1 3)) '() "srlw rd, rs1, rs2")
   (instruction-info "sraw" "rv64_i" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 5) (2 6 14) (0 1 3)) '() "sraw rd, rs1, rs2")
   (instruction-info "sext.w" "rv64_i" 32 '("rd" "rs1") '("rd" "rs1") '((20 31 0) (12 14 0) (2 6 6) (0 1 3)) '() "sext.w rd, rs1")))

(provide rv64_i-instructions)
