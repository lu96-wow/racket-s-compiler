#lang racket/base

(require "struct.rkt")

(define rv_zicfiss-instructions
  (list
   (instruction-info "ssamoswap.w" "rv_zicfiss" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 2) (27 28 1) (12 14 2) (2 6 11) (0 1 3)) '() "ssamoswap.w rd, rs1, rs2, aq, rl")
   (instruction-info "ssamoswap.d" "rv_zicfiss" 32 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 2) (27 28 1) (12 14 3) (2 6 11) (0 1 3)) '() "ssamoswap.d rd, rs1, rs2, aq, rl")
   (instruction-info "sspopchk.x1" "rv_zicfiss" 32 '() '() '((30 30 1) (27 27 1) (26 26 1) (21 21 0) (20 20 0) (31 31 1) (28 29 0) (22 25 7) (15 19 1) (12 14 4) (7 11 0) (2 6 28) (0 1 3)) '() "sspopchk.x1")
   (instruction-info "sspopchk.x5" "rv_zicfiss" 32 '() '() '((30 30 1) (27 27 1) (26 26 1) (21 21 0) (20 20 0) (31 31 1) (28 29 0) (22 25 7) (15 19 5) (12 14 4) (7 11 0) (2 6 28) (0 1 3)) '() "sspopchk.x5")
   (instruction-info "ssrdp" "rv_zicfiss" 32 '("rd_n0") '("rd_n0") '((30 30 1) (27 27 1) (26 26 1) (21 21 0) (20 20 0) (31 31 1) (28 29 0) (22 25 7) (15 19 0) (12 14 4) (2 6 28) (0 1 3)) '() "ssrdp rd_n0")
   (instruction-info "sspush.x1" "rv_zicfiss" 32 '() '() '((30 30 1) (27 27 1) (26 26 1) (31 31 1) (28 29 0) (25 25 1) (20 24 1) (15 19 0) (12 14 4) (7 11 0) (2 6 28) (0 1 3)) '() "sspush.x1")
   (instruction-info "sspush.x5" "rv_zicfiss" 32 '() '() '((30 30 1) (27 27 1) (26 26 1) (31 31 1) (28 29 0) (25 25 1) (20 24 5) (15 19 0) (12 14 4) (7 11 0) (2 6 28) (0 1 3)) '() "sspush.x5")))

(provide
 rv_zicfiss-instructions)
