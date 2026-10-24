#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv32_zbb-instructions
  (list
   (instruction-info 'zext.h.rv32 'rv32_zbb 32 4 '("rd" "rs1") '("rd" "rs1") '((25 31 4) (20 24 0) (12 14 4) (0 6 51)) '() (instruction-origin 'pseudo 'rv_zbkb 'pack) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "zext.h.rv32 rd, rs1")
   (instruction-info 'rev8.rv32 'rv32_zbb 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 1688) (12 14 5) (0 6 19)) '() (instruction-origin 'pseudo 'rv32_zbkb 'rev8.rv32) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "rev8.rv32 rd, rs1")
   (instruction-info 'rori.rv32 'rv32_zbb 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 48) (12 14 5) (2 6 4) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_zbb 'rori) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "rori.rv32 rd, rs1, shamtw")))

(provide
 rv32_zbb-instructions)
