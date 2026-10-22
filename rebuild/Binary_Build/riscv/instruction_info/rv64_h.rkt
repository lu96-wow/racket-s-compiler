#lang racket/base

(require "struct.rkt")

(define rv64_h-instructions
  (list
   (instruction-info "hlv.wu" "rv64_h" 32 '("rd" "rs1") '("rd" "rs1") '((20 24 1) (25 31 52) (12 14 4) (2 6 28) (0 1 3)) '() "hlv.wu rd, rs1")
   (instruction-info "hlv.d" "rv64_h" 32 '("rd" "rs1") '("rd" "rs1") '((20 24 0) (25 31 54) (12 14 4) (2 6 28) (0 1 3)) '() "hlv.d rd, rs1")
   (instruction-info "hsv.d" "rv64_h" 32 '("rs1" "rs2") '("rs1" "rs2") '((7 11 0) (25 31 55) (12 14 4) (2 6 28) (0 1 3)) '() "hsv.d rs1, rs2")))

(provide rv64_h-instructions)
