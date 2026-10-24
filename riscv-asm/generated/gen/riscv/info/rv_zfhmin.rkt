#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zfhmin-instructions
  (list
   (instruction-info 'flh 'rv_zfhmin 32 4 '("rd" "rs1" "imm12") '("rd" "rs1" "imm12") '((12 14 1) (2 6 1) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("imm12" "imm12")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:imm12" "imm12")) "flh rd, rs1, imm12")
   (instruction-info 'fsh 'rv_zfhmin 32 4 '("simm12" "rs1" "rs2") '("imm12hi" "rs1" "rs2" "imm12lo") '((12 14 1) (2 6 9) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("imm12hi" "imm12hi") ("rs1" "rs1") ("rs2" "rs2") ("imm12lo" "imm12lo")) '(("rebuilt:simm12" "simm12") ("raw:rs1" "rs1") ("raw:rs2" "rs2") ("rebuilt:simm12" "simm12")) "fsh simm12, rs1, rs2")
   (instruction-info 'fcvt.s.h 'rv_zfhmin 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 2) (27 31 8) (25 26 0) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rm" "rm")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rm" "rm")) "fcvt.s.h rd, rs1, rm")
   (instruction-info 'fcvt.h.s 'rv_zfhmin 32 4 '("rd" "rs1" "rm") '("rd" "rs1" "rm") '((20 24 0) (27 31 8) (25 26 2) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rm" "rm")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rm" "rm")) "fcvt.h.s rd, rs1, rm")
   (instruction-info 'fmv.x.h 'rv_zfhmin 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 0) (27 31 28) (12 14 0) (25 26 2) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "fmv.x.h rd, rs1")
   (instruction-info 'fmv.h.x 'rv_zfhmin 32 4 '("rd" "rs1") '("rd" "rs1") '((20 24 0) (27 31 30) (12 14 0) (25 26 2) (2 6 20) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "fmv.h.x rd, rs1")))

(provide
 rv_zfhmin-instructions)
