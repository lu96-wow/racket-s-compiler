#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv64_zbkb-instructions
  (list
   (instruction-info 'packw 'rv64_zbkb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 4) (12 14 4) (2 6 14) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "packw rd, rs1, rs2")
   (instruction-info 'rolw 'rv64_zbkb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 1) (2 6 14) (0 1 3)) '() (instruction-origin 'import 'rv64_zbb 'rolw) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "rolw rd, rs1, rs2")
   (instruction-info 'rorw 'rv64_zbkb 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 5) (2 6 14) (0 1 3)) '() (instruction-origin 'import 'rv64_zbb 'rorw) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "rorw rd, rs1, rs2")
   (instruction-info 'roriw 'rv64_zbkb 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 48) (12 14 5) (2 6 6) (0 1 3)) '() (instruction-origin 'import 'rv64_zbb 'roriw) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "roriw rd, rs1, shamtw")
   (instruction-info 'rori 'rv64_zbkb 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 24) (12 14 5) (2 6 4) (0 1 3)) '() (instruction-origin 'import 'rv64_zbb 'rori) '(("rd" "rd") ("rs1" "rs1") ("shamtd" "shamtd")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtd" "shamtd")) "rori rd, rs1, shamtd")
   (instruction-info 'rev8 'rv64_zbkb 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 1720) (12 14 5) (0 6 19)) '() (instruction-origin 'pseudo 'rv64_zbb 'rev8) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "rev8 rd, rs1")))

(provide
 rv64_zbkb-instructions)
