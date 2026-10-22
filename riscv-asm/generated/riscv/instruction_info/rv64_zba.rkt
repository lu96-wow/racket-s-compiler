#lang racket/base

(require "struct.rkt")

(define rv64_zba-instructions
  (list
   (instruction-info "add.uw" "rv64_zba" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 4) (12 14 0) (2 6 14) (0 1 3)) '() "add.uw rd, rs1, rs2")
   (instruction-info "sh1add.uw" "rv64_zba" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 16) (12 14 2) (2 6 14) (0 1 3)) '() "sh1add.uw rd, rs1, rs2")
   (instruction-info "sh2add.uw" "rv64_zba" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 16) (12 14 4) (2 6 14) (0 1 3)) '() "sh2add.uw rd, rs1, rs2")
   (instruction-info "sh3add.uw" "rv64_zba" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 16) (12 14 6) (2 6 14) (0 1 3)) '() "sh3add.uw rd, rs1, rs2")
   (instruction-info "slli.uw" "rv64_zba" 32 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 2) (12 14 1) (2 6 6) (0 1 3)) '() "slli.uw rd, rs1, shamtd")
   (instruction-info "zext.w" "rv64_zba" 32 '("rd" "rs1") '("rd" "rs1") '((25 31 4) (20 24 0) (12 14 0) (2 6 14) (0 1 3)) '() "zext.w rd, rs1")))

(provide
 rv64_zba-instructions)
