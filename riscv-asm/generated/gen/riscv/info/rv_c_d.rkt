#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_c_d-instructions
  (list
   (instruction-info 'c.fld 'rv_c_d 16 2 '("rd_p" "rs1_p" "c_uimm8") '("rd_p" "rs1_p" "c_uimm8lo" "c_uimm8hi") '((0 1 0) (13 15 1)) '() (instruction-origin 'standard #f #f) '(("rd_p" "rd_p") ("rs1_p" "rs1_p") ("c_uimm8lo" "c_uimm8lo") ("c_uimm8hi" "c_uimm8hi")) '(("raw:rd_p" "rd_p") ("raw:rs1_p" "rs1_p") ("rebuilt:c_uimm8" "c_uimm8") ("rebuilt:c_uimm8" "c_uimm8")) "c.fld rd_p, rs1_p, c_uimm8")
   (instruction-info 'c.fsd 'rv_c_d 16 2 '("rs1_p" "rs2_p" "c_uimm8") '("rs1_p" "rs2_p" "c_uimm8lo" "c_uimm8hi") '((0 1 0) (13 15 5)) '() (instruction-origin 'standard #f #f) '(("rs1_p" "rs1_p") ("rs2_p" "rs2_p") ("c_uimm8lo" "c_uimm8lo") ("c_uimm8hi" "c_uimm8hi")) '(("raw:rs1_p" "rs1_p") ("raw:rs2_p" "rs2_p") ("rebuilt:c_uimm8" "c_uimm8") ("rebuilt:c_uimm8" "c_uimm8")) "c.fsd rs1_p, rs2_p, c_uimm8")
   (instruction-info 'c.fldsp 'rv_c_d 16 2 '("rd" "c_uimm9sp") '("rd" "c_uimm9sphi" "c_uimm9splo") '((0 1 2) (13 15 1)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("c_uimm9sphi" "c_uimm9sphi") ("c_uimm9splo" "c_uimm9splo")) '(("raw:rd" "rd") ("rebuilt:c_uimm9sp" "c_uimm9sp") ("rebuilt:c_uimm9sp" "c_uimm9sp")) "c.fldsp rd, c_uimm9sp")
   (instruction-info 'c.fsdsp 'rv_c_d 16 2 '("c_rs2" "c_uimm9sp_s") '("c_rs2" "c_uimm9sp_s") '((0 1 2) (13 15 5)) '() (instruction-origin 'standard #f #f) '(("c_rs2" "c_rs2") ("c_uimm9sp_s" "c_uimm9sp_s")) '(("raw:c_rs2" "c_rs2") ("raw:c_uimm9sp_s" "c_uimm9sp_s")) "c.fsdsp c_rs2, c_uimm9sp_s")))

(provide
 rv_c_d-instructions)
