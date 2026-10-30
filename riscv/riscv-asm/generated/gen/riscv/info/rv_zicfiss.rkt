#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zicfiss-instructions
  (list
   (instruction-info 'ssamoswap.w 'rv_zicfiss 32 4 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 2) (27 28 1) (12 14 2) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2") ("aq" "aq") ("rl" "rl")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:aq" "aq") ("raw:rl" "rl")) "ssamoswap.w rd, rs1, rs2, aq, rl")
   (instruction-info 'ssamoswap.d 'rv_zicfiss 32 4 '("rd" "rs1" "rs2" "aq" "rl") '("rd" "rs1" "rs2" "aq" "rl") '((29 31 2) (27 28 1) (12 14 3) (2 6 11) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2") ("aq" "aq") ("rl" "rl")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2") ("raw:aq" "aq") ("raw:rl" "rl")) "ssamoswap.d rd, rs1, rs2, aq, rl")
   (instruction-info 'sspopchk.x1 'rv_zicfiss 32 4 '() '() '((30 30 1) (27 27 1) (26 26 1) (21 21 0) (20 20 0) (31 31 1) (28 29 0) (22 25 7) (15 19 1) (12 14 4) (7 11 0) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zimop 'mop.r.N) '() '() "sspopchk.x1")
   (instruction-info 'sspopchk.x5 'rv_zicfiss 32 4 '() '() '((30 30 1) (27 27 1) (26 26 1) (21 21 0) (20 20 0) (31 31 1) (28 29 0) (22 25 7) (15 19 5) (12 14 4) (7 11 0) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zimop 'mop.r.N) '() '() "sspopchk.x5")
   (instruction-info 'ssrdp 'rv_zicfiss 32 4 '("rd_n0") '("rd_n0") '((30 30 1) (27 27 1) (26 26 1) (21 21 0) (20 20 0) (31 31 1) (28 29 0) (22 25 7) (15 19 0) (12 14 4) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zimop 'mop.r.N) '(("rd_n0" "rd_n0")) '(("raw:rd_n0" "rd_n0")) "ssrdp rd_n0")
   (instruction-info 'sspush.x1 'rv_zicfiss 32 4 '() '() '((30 30 1) (27 27 1) (26 26 1) (31 31 1) (28 29 0) (25 25 1) (20 24 1) (15 19 0) (12 14 4) (7 11 0) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zimop 'mop.rr.N) '() '() "sspush.x1")
   (instruction-info 'sspush.x5 'rv_zicfiss 32 4 '() '() '((30 30 1) (27 27 1) (26 26 1) (31 31 1) (28 29 0) (25 25 1) (20 24 5) (15 19 0) (12 14 4) (7 11 0) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zimop 'mop.rr.N) '() '() "sspush.x5")))

(provide
 rv_zicfiss-instructions)
