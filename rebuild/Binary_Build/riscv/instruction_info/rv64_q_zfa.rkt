#lang racket/base

(require "struct.rkt")

(define rv64_q_zfa-instructions
  (list
   (instruction-info "fmvh.x.q" "rv64_q_zfa" 32 '("rd" "rs1") '("rd" "rs1") '((20 24 1) (27 31 28) (12 14 0) (25 26 3) (2 6 20) (0 1 3)) '() "fmvh.x.q rd, rs1")
   (instruction-info "fmvp.q.x" "rv64_q_zfa" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((27 31 22) (12 14 0) (25 26 3) (2 6 20) (0 1 3)) '() "fmvp.q.x rd, rs1, rs2")))

(provide rv64_q_zfa-instructions)
