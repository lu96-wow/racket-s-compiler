#lang racket/base

(require "struct.rkt")

(define rv_zbkb-instructions
  (list
   (instruction-info "pack" "rv_zbkb" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 4) (12 14 4) (2 6 12) (0 1 3)) '() "pack rd, rs1, rs2")
   (instruction-info "packh" "rv_zbkb" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 4) (12 14 7) (2 6 12) (0 1 3)) '() "packh rd, rs1, rs2")
   (instruction-info "brev8" "rv_zbkb" 32 '("rd" "rs1") '("rd" "rs1") '((20 31 1671) (12 14 5) (2 6 4) (0 1 3)) '() "brev8 rd, rs1")
   (instruction-info "rol" "rv_zbkb" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 1) (2 6 12) (0 1 3)) '() "rol rd, rs1, rs2")
   (instruction-info "ror" "rv_zbkb" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 5) (2 6 12) (0 1 3)) '() "ror rd, rs1, rs2")
   (instruction-info "andn" "rv_zbkb" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 7) (2 6 12) (0 1 3)) '() "andn rd, rs1, rs2")
   (instruction-info "orn" "rv_zbkb" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 6) (2 6 12) (0 1 3)) '() "orn rd, rs1, rs2")
   (instruction-info "xnor" "rv_zbkb" 32 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 4) (2 6 12) (0 1 3)) '() "xnor rd, rs1, rs2")))

(provide rv_zbkb-instructions)
