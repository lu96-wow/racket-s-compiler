#lang racket/base

(require "struct.rkt")

(define rv64_m-instructions
  (list
   (instruction-info "mulw" "rv64_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 0) (2 6 14) (0 1 3)) '() "mulw rd, rs1, rs2")
   (instruction-info "divw" "rv64_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 4) (2 6 14) (0 1 3)) '() "divw rd, rs1, rs2")
   (instruction-info "divuw" "rv64_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 5) (2 6 14) (0 1 3)) '() "divuw rd, rs1, rs2")
   (instruction-info "remw" "rv64_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 6) (2 6 14) (0 1 3)) '() "remw rd, rs1, rs2")
   (instruction-info "remuw" "rv64_m" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 1) (12 14 7) (2 6 14) (0 1 3)) '() "remuw rd, rs1, rs2")))

(provide rv64_m-instructions)
