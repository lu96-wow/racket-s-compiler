#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv32_zclsd-instructions
  (list
   (instruction-info 'c.ld 'rv32_zclsd 16 2 '("rd_p_e" "rs1_p" "c_uimm8") '("rd_p_e" "rs1_p" "c_uimm8lo" "c_uimm8hi") '((0 2 0) (13 15 3)) '() (instruction-origin 'pseudo 'rv32_c_f 'c.flw) '(("rd_p_e" "rd_p_e") ("rs1_p" "rs1_p") ("c_uimm8lo" "c_uimm8lo") ("c_uimm8hi" "c_uimm8hi")) '(("raw:rd_p_e" "rd_p_e") ("raw:rs1_p" "rs1_p") ("rebuilt:c_uimm8" "c_uimm8") ("rebuilt:c_uimm8" "c_uimm8")) "c.ld rd_p_e, rs1_p, c_uimm8")
   (instruction-info 'c.sd 'rv32_zclsd 16 2 '("rs1_p" "rs2_p_e" "c_uimm8") '("rs1_p" "rs2_p_e" "c_uimm8hi" "c_uimm8lo") '((0 2 0) (13 15 7)) '() (instruction-origin 'pseudo 'rv32_c_f 'c.fsw) '(("rs1_p" "rs1_p") ("rs2_p_e" "rs2_p_e") ("c_uimm8hi" "c_uimm8hi") ("c_uimm8lo" "c_uimm8lo")) '(("raw:rs1_p" "rs1_p") ("raw:rs2_p_e" "rs2_p_e") ("rebuilt:c_uimm8" "c_uimm8") ("rebuilt:c_uimm8" "c_uimm8")) "c.sd rs1_p, rs2_p_e, c_uimm8")
   (instruction-info 'c.ldsp 'rv32_zclsd 16 2 '("rd_n0_e" "c_uimm9sp") '("rd_n0_e" "c_uimm9sphi" "c_uimm9splo") '((0 1 2) (13 15 3) (7 7 0)) '() (instruction-origin 'pseudo 'rv32_c_f 'c.flwsp) '(("rd_n0_e" "rd_n0_e") ("c_uimm9sphi" "c_uimm9sphi") ("c_uimm9splo" "c_uimm9splo")) '(("raw:rd_n0_e" "rd_n0_e") ("rebuilt:c_uimm9sp" "c_uimm9sp") ("rebuilt:c_uimm9sp" "c_uimm9sp")) "c.ldsp rd_n0_e, c_uimm9sp")
   (instruction-info 'c.sdsp 'rv32_zclsd 16 2 '("c_rs2_e" "c_uimm9sp_s") '("c_rs2_e" "c_uimm9sp_s") '((0 2 2) (13 15 7)) '() (instruction-origin 'pseudo 'rv32_c_f 'c.fswsp) '(("c_rs2_e" "c_rs2_e") ("c_uimm9sp_s" "c_uimm9sp_s")) '(("raw:c_rs2_e" "c_rs2_e") ("raw:c_uimm9sp_s" "c_uimm9sp_s")) "c.sdsp c_rs2_e, c_uimm9sp_s")))

(provide
 rv32_zclsd-instructions)
