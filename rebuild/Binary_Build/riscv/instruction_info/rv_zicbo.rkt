#lang racket/base

(require "struct.rkt")

(define rv_zicbo-instructions
  (list
   (instruction-info "cbo.clean" "rv_zicbo" 32 '("rs1") '("rs1") '((20 31 1) (12 14 2) (7 11 0) (2 6 3) (0 1 3)) '() "cbo.clean rs1")
   (instruction-info "cbo.flush" "rv_zicbo" 32 '("rs1") '("rs1") '((20 31 2) (12 14 2) (7 11 0) (2 6 3) (0 1 3)) '() "cbo.flush rs1")
   (instruction-info "cbo.inval" "rv_zicbo" 32 '("rs1") '("rs1") '((20 31 0) (12 14 2) (7 11 0) (2 6 3) (0 1 3)) '() "cbo.inval rs1")
   (instruction-info "cbo.zero" "rv_zicbo" 32 '("rs1") '("rs1") '((20 31 4) (12 14 2) (7 11 0) (2 6 3) (0 1 3)) '() "cbo.zero rs1")
   (instruction-info "prefetch.i" "rv_zicbo" 32 '("rs1" "imm12hi") '("rs1" "imm12hi") '((20 24 0) (12 14 6) (7 11 0) (2 6 4) (0 1 3)) '() "prefetch.i rs1, imm12hi")
   (instruction-info "prefetch.r" "rv_zicbo" 32 '("rs1" "imm12hi") '("rs1" "imm12hi") '((20 24 1) (12 14 6) (7 11 0) (2 6 4) (0 1 3)) '() "prefetch.r rs1, imm12hi")
   (instruction-info "prefetch.w" "rv_zicbo" 32 '("rs1" "imm12hi") '("rs1" "imm12hi") '((20 24 3) (12 14 6) (7 11 0) (2 6 4) (0 1 3)) '() "prefetch.w rs1, imm12hi")))

(provide
 rv_zicbo-instructions)
