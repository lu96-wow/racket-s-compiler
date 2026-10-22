#lang racket/base

(require "struct.rkt")

(define rv64_a-instructions
  (list
   (instruction-info "lr.d" "rv64_a" 32 '("rd" "rs1" "aq" "rl") '("rd" "rs1" "aq" "rl") '((20 24 0) (29 31 0) (27 28 2) (12 14 3) (2 6 11) (0 1 3)) '() "lr.d rd, rs1, aq, rl")
   (instruction-info "sc.d" "rv64_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 0) (27 28 3) (12 14 3) (2 6 11) (0 1 3)) '() "sc.d rd, rs1, rs2, aq, rl")
   (instruction-info "amoswap.d" "rv64_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 0) (27 28 1) (12 14 3) (2 6 11) (0 1 3)) '() "amoswap.d rd, rs1, rs2, aq, rl")
   (instruction-info "amoadd.d" "rv64_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 0) (27 28 0) (12 14 3) (2 6 11) (0 1 3)) '() "amoadd.d rd, rs1, rs2, aq, rl")
   (instruction-info "amoxor.d" "rv64_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 1) (27 28 0) (12 14 3) (2 6 11) (0 1 3)) '() "amoxor.d rd, rs1, rs2, aq, rl")
   (instruction-info "amoand.d" "rv64_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 3) (27 28 0) (12 14 3) (2 6 11) (0 1 3)) '() "amoand.d rd, rs1, rs2, aq, rl")
   (instruction-info "amoor.d" "rv64_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 2) (27 28 0) (12 14 3) (2 6 11) (0 1 3)) '() "amoor.d rd, rs1, rs2, aq, rl")
   (instruction-info "amomin.d" "rv64_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 4) (27 28 0) (12 14 3) (2 6 11) (0 1 3)) '() "amomin.d rd, rs1, rs2, aq, rl")
   (instruction-info "amomax.d" "rv64_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 5) (27 28 0) (12 14 3) (2 6 11) (0 1 3)) '() "amomax.d rd, rs1, rs2, aq, rl")
   (instruction-info "amominu.d" "rv64_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 6) (27 28 0) (12 14 3) (2 6 11) (0 1 3)) '() "amominu.d rd, rs1, rs2, aq, rl")
   (instruction-info "amomaxu.d" "rv64_a" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 7) (27 28 0) (12 14 3) (2 6 11) (0 1 3)) '() "amomaxu.d rd, rs1, rs2, aq, rl")))

(provide rv64_a-instructions)
