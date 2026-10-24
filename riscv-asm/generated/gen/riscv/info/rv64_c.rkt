#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv64_c-instructions
  (list
   (instruction-info 'c.ld 'rv64_c 16 2 '("rd_p" "rs1_p" "c_uimm8") '("rd_p" "rs1_p" "c_uimm8lo" "c_uimm8hi") '((0 1 0) (13 15 3)) '() (instruction-origin 'standard #f #f) '(("rd_p" "rd_p") ("rs1_p" "rs1_p") ("c_uimm8lo" "c_uimm8lo") ("c_uimm8hi" "c_uimm8hi")) '(("raw:rd_p" "rd_p") ("raw:rs1_p" "rs1_p") ("rebuilt:c_uimm8" "c_uimm8") ("rebuilt:c_uimm8" "c_uimm8")) "c.ld rd_p, rs1_p, c_uimm8")
   (instruction-info 'c.sd 'rv64_c 16 2 '("rs1_p" "rs2_p" "c_uimm8") '("rs1_p" "rs2_p" "c_uimm8hi" "c_uimm8lo") '((0 1 0) (13 15 7)) '() (instruction-origin 'standard #f #f) '(("rs1_p" "rs1_p") ("rs2_p" "rs2_p") ("c_uimm8hi" "c_uimm8hi") ("c_uimm8lo" "c_uimm8lo")) '(("raw:rs1_p" "rs1_p") ("raw:rs2_p" "rs2_p") ("rebuilt:c_uimm8" "c_uimm8") ("rebuilt:c_uimm8" "c_uimm8")) "c.sd rs1_p, rs2_p, c_uimm8")
   (instruction-info 'c.addiw 'rv64_c 16 2 '("rd_rs1_n0" "c_imm6") '("rd_rs1_n0" "c_imm6lo" "c_imm6hi") '((0 1 1) (13 15 1)) '() (instruction-origin 'standard #f #f) '(("rd_rs1_n0" "rd_rs1_n0") ("c_imm6lo" "c_imm6lo") ("c_imm6hi" "c_imm6hi")) '(("raw:rd_rs1_n0" "rd_rs1_n0") ("rebuilt:c_imm6" "c_imm6") ("rebuilt:c_imm6" "c_imm6")) "c.addiw rd_rs1_n0, c_imm6")
   (instruction-info 'c.srli 'rv64_c 16 2 '("rd_rs1_p" "c_nzuimm6") '("rd_rs1_p" "c_nzuimm6lo" "c_nzuimm6hi") '((0 1 1) (13 15 4) (10 11 0)) '() (instruction-origin 'standard #f #f) '(("rd_rs1_p" "rd_rs1_p") ("c_nzuimm6lo" "c_nzuimm6lo") ("c_nzuimm6hi" "c_nzuimm6hi")) '(("raw:rd_rs1_p" "rd_rs1_p") ("rebuilt:c_nzuimm6" "c_nzuimm6") ("rebuilt:c_nzuimm6" "c_nzuimm6")) "c.srli rd_rs1_p, c_nzuimm6")
   (instruction-info 'c.srai 'rv64_c 16 2 '("rd_rs1_p" "c_nzuimm6") '("rd_rs1_p" "c_nzuimm6lo" "c_nzuimm6hi") '((0 1 1) (13 15 4) (10 11 1)) '() (instruction-origin 'standard #f #f) '(("rd_rs1_p" "rd_rs1_p") ("c_nzuimm6lo" "c_nzuimm6lo") ("c_nzuimm6hi" "c_nzuimm6hi")) '(("raw:rd_rs1_p" "rd_rs1_p") ("rebuilt:c_nzuimm6" "c_nzuimm6") ("rebuilt:c_nzuimm6" "c_nzuimm6")) "c.srai rd_rs1_p, c_nzuimm6")
   (instruction-info 'c.subw 'rv64_c 16 2 '("rd_rs1_p" "rs2_p") '("rd_rs1_p" "rs2_p") '((0 1 1) (13 15 4) (10 12 7) (5 6 0)) '() (instruction-origin 'standard #f #f) '(("rd_rs1_p" "rd_rs1_p") ("rs2_p" "rs2_p")) '(("raw:rd_rs1_p" "rd_rs1_p") ("raw:rs2_p" "rs2_p")) "c.subw rd_rs1_p, rs2_p")
   (instruction-info 'c.addw 'rv64_c 16 2 '("rd_rs1_p" "rs2_p") '("rd_rs1_p" "rs2_p") '((0 1 1) (13 15 4) (10 12 7) (5 6 1)) '() (instruction-origin 'standard #f #f) '(("rd_rs1_p" "rd_rs1_p") ("rs2_p" "rs2_p")) '(("raw:rd_rs1_p" "rd_rs1_p") ("raw:rs2_p" "rs2_p")) "c.addw rd_rs1_p, rs2_p")
   (instruction-info 'c.slli 'rv64_c 16 2 '("rd_rs1_n0" "c_nzuimm6") '("rd_rs1_n0" "c_nzuimm6hi" "c_nzuimm6lo") '((0 1 2) (13 15 0)) '() (instruction-origin 'standard #f #f) '(("rd_rs1_n0" "rd_rs1_n0") ("c_nzuimm6hi" "c_nzuimm6hi") ("c_nzuimm6lo" "c_nzuimm6lo")) '(("raw:rd_rs1_n0" "rd_rs1_n0") ("rebuilt:c_nzuimm6" "c_nzuimm6") ("rebuilt:c_nzuimm6" "c_nzuimm6")) "c.slli rd_rs1_n0, c_nzuimm6")
   (instruction-info 'c.ldsp 'rv64_c 16 2 '("rd_n0" "c_uimm9sp") '("rd_n0" "c_uimm9sphi" "c_uimm9splo") '((0 1 2) (13 15 3)) '() (instruction-origin 'standard #f #f) '(("rd_n0" "rd_n0") ("c_uimm9sphi" "c_uimm9sphi") ("c_uimm9splo" "c_uimm9splo")) '(("raw:rd_n0" "rd_n0") ("rebuilt:c_uimm9sp" "c_uimm9sp") ("rebuilt:c_uimm9sp" "c_uimm9sp")) "c.ldsp rd_n0, c_uimm9sp")
   (instruction-info 'c.sdsp 'rv64_c 16 2 '("c_rs2" "c_uimm9sp_s") '("c_rs2" "c_uimm9sp_s") '((0 1 2) (13 15 7)) '() (instruction-origin 'standard #f #f) '(("c_rs2" "c_rs2") ("c_uimm9sp_s" "c_uimm9sp_s")) '(("raw:c_rs2" "c_rs2") ("raw:c_uimm9sp_s" "c_uimm9sp_s")) "c.sdsp c_rs2, c_uimm9sp_s")))

(provide
 rv64_c-instructions)
