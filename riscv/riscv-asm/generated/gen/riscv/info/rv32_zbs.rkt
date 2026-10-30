#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv32_zbs-instructions
  (list
   (instruction-info 'bclri.rv32 'rv32_zbs 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 36) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_zbs 'bclri) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "bclri.rv32 rd, rs1, shamtw")
   (instruction-info 'bexti.rv32 'rv32_zbs 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 36) (12 14 5) (2 6 4) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_zbs 'bexti) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "bexti.rv32 rd, rs1, shamtw")
   (instruction-info 'binvi.rv32 'rv32_zbs 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 52) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_zbs 'binvi) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "binvi.rv32 rd, rs1, shamtw")
   (instruction-info 'bseti.rv32 'rv32_zbs 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 20) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_zbs 'bseti) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "bseti.rv32 rd, rs1, shamtw")))

(provide
 rv32_zbs-instructions)
