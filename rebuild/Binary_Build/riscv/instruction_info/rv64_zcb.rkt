#lang racket/base

(require "struct.rkt")

(define rv64_zcb-instructions
  (list
   (instruction-info "c.zext.w" "rv64_zcb" 16 '("rd_rs1_p") '("rd_rs1_p") '((0 1 1) (13 15 4) (10 12 7) (5 6 3) (2 4 4)) '() "c.zext.w rd_rs1_p")
   (instruction-info "c.sext.w" "rv64_zcb" 16 '("rd_rs1_n0") '("rd_rs1_n0") '((13 15 1) (12 12 0) (2 6 0) (0 1 1)) '() "c.sext.w rd_rs1_n0")))

(provide rv64_zcb-instructions)
