#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv32_i-instructions
  (list
   (instruction-info 'slli 'rv32_i 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 0) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_i 'slli) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "slli rd, rs1, shamtw")
   (instruction-info 'srli 'rv32_i 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 0) (12 14 5) (2 6 4) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_i 'srli) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "srli rd, rs1, shamtw")
   (instruction-info 'srai 'rv32_i 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 32) (12 14 5) (2 6 4) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_i 'srai) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "srai rd, rs1, shamtw")
   (instruction-info 'slli_rv32 'rv32_i 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 0) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_i 'slli) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "slli_rv32 rd, rs1, shamtw")
   (instruction-info 'srli_rv32 'rv32_i 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 0) (12 14 5) (2 6 4) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_i 'srli) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "srli_rv32 rd, rs1, shamtw")
   (instruction-info 'srai_rv32 'rv32_i 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 32) (12 14 5) (2 6 4) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_i 'srai) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "srai_rv32 rd, rs1, shamtw")))

(provide
 rv32_i-instructions)
