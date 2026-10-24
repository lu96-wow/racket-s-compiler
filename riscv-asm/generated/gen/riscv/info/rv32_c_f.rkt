#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv32_c_f-instructions
  (list
   (instruction-info 'c.flw 'rv32_c_f 16 2 '("rd_p" "rs1_p" "c_uimm7") '("rd_p" "rs1_p" "c_uimm7lo" "c_uimm7hi") '((0 1 0) (13 15 3)) '() (instruction-origin 'standard #f #f) '(("rd_p" "rd_p") ("rs1_p" "rs1_p") ("c_uimm7lo" "c_uimm7lo") ("c_uimm7hi" "c_uimm7hi")) '(("raw:rd_p" "rd_p") ("raw:rs1_p" "rs1_p") ("rebuilt:c_uimm7" "c_uimm7") ("rebuilt:c_uimm7" "c_uimm7")) "c.flw rd_p, rs1_p, c_uimm7")
   (instruction-info 'c.fsw 'rv32_c_f 16 2 '("rs1_p" "rs2_p" "c_uimm7") '("rs1_p" "rs2_p" "c_uimm7lo" "c_uimm7hi") '((0 1 0) (13 15 7)) '() (instruction-origin 'standard #f #f) '(("rs1_p" "rs1_p") ("rs2_p" "rs2_p") ("c_uimm7lo" "c_uimm7lo") ("c_uimm7hi" "c_uimm7hi")) '(("raw:rs1_p" "rs1_p") ("raw:rs2_p" "rs2_p") ("rebuilt:c_uimm7" "c_uimm7") ("rebuilt:c_uimm7" "c_uimm7")) "c.fsw rs1_p, rs2_p, c_uimm7")
   (instruction-info 'c.flwsp 'rv32_c_f 16 2 '("rd" "c_uimm8sp") '("rd" "c_uimm8sphi" "c_uimm8splo") '((0 1 2) (13 15 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("c_uimm8sphi" "c_uimm8sphi") ("c_uimm8splo" "c_uimm8splo")) '(("raw:rd" "rd") ("rebuilt:c_uimm8sp" "c_uimm8sp") ("rebuilt:c_uimm8sp" "c_uimm8sp")) "c.flwsp rd, c_uimm8sp")
   (instruction-info 'c.fswsp 'rv32_c_f 16 2 '("c_rs2" "c_uimm8sp_s") '("c_rs2" "c_uimm8sp_s") '((0 1 2) (13 15 7)) '() (instruction-origin 'standard #f #f) '(("c_rs2" "c_rs2") ("c_uimm8sp_s" "c_uimm8sp_s")) '(("raw:c_rs2" "c_rs2") ("raw:c_uimm8sp_s" "c_uimm8sp_s")) "c.fswsp c_rs2, c_uimm8sp_s")))

(provide
 rv32_c_f-instructions)
