#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zcb-instructions
  (list
   (instruction-info 'c.lbu 'rv_zcb 16 2 '("rd_p" "rs1_p" "c_uimm2") '("rd_p" "rs1_p" "c_uimm2") '((0 1 0) (13 15 4) (10 12 0)) '() (instruction-origin 'standard #f #f) '(("rd_p" "rd_p") ("rs1_p" "rs1_p") ("c_uimm2" "c_uimm2")) '(("raw:rd_p" "rd_p") ("raw:rs1_p" "rs1_p") ("raw:c_uimm2" "c_uimm2")) "c.lbu rd_p, rs1_p, c_uimm2")
   (instruction-info 'c.lhu 'rv_zcb 16 2 '("rd_p" "rs1_p" "c_uimm1") '("rd_p" "rs1_p" "c_uimm1") '((0 1 0) (13 15 4) (10 12 1) (6 6 0)) '() (instruction-origin 'standard #f #f) '(("rd_p" "rd_p") ("rs1_p" "rs1_p") ("c_uimm1" "c_uimm1")) '(("raw:rd_p" "rd_p") ("raw:rs1_p" "rs1_p") ("raw:c_uimm1" "c_uimm1")) "c.lhu rd_p, rs1_p, c_uimm1")
   (instruction-info 'c.lh 'rv_zcb 16 2 '("rd_p" "rs1_p" "c_uimm1") '("rd_p" "rs1_p" "c_uimm1") '((0 1 0) (13 15 4) (10 12 1) (6 6 1)) '() (instruction-origin 'standard #f #f) '(("rd_p" "rd_p") ("rs1_p" "rs1_p") ("c_uimm1" "c_uimm1")) '(("raw:rd_p" "rd_p") ("raw:rs1_p" "rs1_p") ("raw:c_uimm1" "c_uimm1")) "c.lh rd_p, rs1_p, c_uimm1")
   (instruction-info 'c.sb 'rv_zcb 16 2 '("rs2_p" "rs1_p" "c_uimm2") '("rs2_p" "rs1_p" "c_uimm2") '((0 1 0) (13 15 4) (10 12 2)) '() (instruction-origin 'standard #f #f) '(("rs2_p" "rs2_p") ("rs1_p" "rs1_p") ("c_uimm2" "c_uimm2")) '(("raw:rs2_p" "rs2_p") ("raw:rs1_p" "rs1_p") ("raw:c_uimm2" "c_uimm2")) "c.sb rs2_p, rs1_p, c_uimm2")
   (instruction-info 'c.sh 'rv_zcb 16 2 '("rs2_p" "rs1_p" "c_uimm1") '("rs2_p" "rs1_p" "c_uimm1") '((0 1 0) (13 15 4) (10 12 3) (6 6 0)) '() (instruction-origin 'standard #f #f) '(("rs2_p" "rs2_p") ("rs1_p" "rs1_p") ("c_uimm1" "c_uimm1")) '(("raw:rs2_p" "rs2_p") ("raw:rs1_p" "rs1_p") ("raw:c_uimm1" "c_uimm1")) "c.sh rs2_p, rs1_p, c_uimm1")
   (instruction-info 'c.zext.b 'rv_zcb 16 2 '("rd_rs1_p") '("rd_rs1_p") '((0 1 1) (13 15 4) (10 12 7) (5 6 3) (2 4 0)) '() (instruction-origin 'standard #f #f) '(("rd_rs1_p" "rd_rs1_p")) '(("raw:rd_rs1_p" "rd_rs1_p")) "c.zext.b rd_rs1_p")
   (instruction-info 'c.sext.b 'rv_zcb 16 2 '("rd_rs1_p") '("rd_rs1_p") '((0 1 1) (13 15 4) (10 12 7) (5 6 3) (2 4 1)) '() (instruction-origin 'standard #f #f) '(("rd_rs1_p" "rd_rs1_p")) '(("raw:rd_rs1_p" "rd_rs1_p")) "c.sext.b rd_rs1_p")
   (instruction-info 'c.zext.h 'rv_zcb 16 2 '("rd_rs1_p") '("rd_rs1_p") '((0 1 1) (13 15 4) (10 12 7) (5 6 3) (2 4 2)) '() (instruction-origin 'standard #f #f) '(("rd_rs1_p" "rd_rs1_p")) '(("raw:rd_rs1_p" "rd_rs1_p")) "c.zext.h rd_rs1_p")
   (instruction-info 'c.sext.h 'rv_zcb 16 2 '("rd_rs1_p") '("rd_rs1_p") '((0 1 1) (13 15 4) (10 12 7) (5 6 3) (2 4 3)) '() (instruction-origin 'standard #f #f) '(("rd_rs1_p" "rd_rs1_p")) '(("raw:rd_rs1_p" "rd_rs1_p")) "c.sext.h rd_rs1_p")
   (instruction-info 'c.not 'rv_zcb 16 2 '("rd_rs1_p") '("rd_rs1_p") '((0 1 1) (13 15 4) (10 12 7) (5 6 3) (2 4 5)) '() (instruction-origin 'standard #f #f) '(("rd_rs1_p" "rd_rs1_p")) '(("raw:rd_rs1_p" "rd_rs1_p")) "c.not rd_rs1_p")
   (instruction-info 'c.mul 'rv_zcb 16 2 '("rd_rs1_p" "rs2_p") '("rd_rs1_p" "rs2_p") '((0 1 1) (13 15 4) (10 12 7) (5 6 2)) '() (instruction-origin 'standard #f #f) '(("rd_rs1_p" "rd_rs1_p") ("rs2_p" "rs2_p")) '(("raw:rd_rs1_p" "rd_rs1_p") ("raw:rs2_p" "rs2_p")) "c.mul rd_rs1_p, rs2_p")))

(provide
 rv_zcb-instructions)
