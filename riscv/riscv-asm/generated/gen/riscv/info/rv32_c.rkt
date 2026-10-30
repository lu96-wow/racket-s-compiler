#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv32_c-instructions
  (list
   (instruction-info 'c.jal 'rv32_c 16 2 '("c_imm12") '("c_imm12") '((0 1 1) (13 15 1)) '() (instruction-origin 'standard #f #f) '(("c_imm12" "c_imm12")) '(("raw:c_imm12" "c_imm12")) "c.jal c_imm12")
   (instruction-info 'c.srli 'rv32_c 16 2 '("rd_rs1_p" "c_nzuimm5") '("rd_rs1_p" "c_nzuimm5") '((0 1 1) (13 15 4) (10 12 0)) '() (instruction-origin 'pseudo 'rv64_c 'c.srli) '(("rd_rs1_p" "rd_rs1_p") ("c_nzuimm5" "c_nzuimm5")) '(("raw:rd_rs1_p" "rd_rs1_p") ("raw:c_nzuimm5" "c_nzuimm5")) "c.srli rd_rs1_p, c_nzuimm5")
   (instruction-info 'c.srai 'rv32_c 16 2 '("rd_rs1_p" "c_nzuimm5") '("rd_rs1_p" "c_nzuimm5") '((0 1 1) (13 15 4) (10 12 1)) '() (instruction-origin 'pseudo 'rv64_c 'c.srai) '(("rd_rs1_p" "rd_rs1_p") ("c_nzuimm5" "c_nzuimm5")) '(("raw:rd_rs1_p" "rd_rs1_p") ("raw:c_nzuimm5" "c_nzuimm5")) "c.srai rd_rs1_p, c_nzuimm5")
   (instruction-info 'c.slli 'rv32_c 16 2 '("rd_rs1_n0" "c_nzuimm6lo") '("rd_rs1_n0" "c_nzuimm6lo") '((0 1 2) (12 15 0)) '() (instruction-origin 'pseudo 'rv64_c 'c.slli) '(("rd_rs1_n0" "rd_rs1_n0") ("c_nzuimm6lo" "c_nzuimm6lo")) '(("raw:rd_rs1_n0" "rd_rs1_n0") ("raw:c_nzuimm6lo" "c_nzuimm6lo")) "c.slli rd_rs1_n0, c_nzuimm6lo")
   (instruction-info 'c.srli_rv32 'rv32_c 16 2 '("rd_rs1_p" "c_nzuimm5") '("rd_rs1_p" "c_nzuimm5") '((0 1 1) (13 15 4) (10 12 0)) '() (instruction-origin 'pseudo 'rv64_c 'c.srli) '(("rd_rs1_p" "rd_rs1_p") ("c_nzuimm5" "c_nzuimm5")) '(("raw:rd_rs1_p" "rd_rs1_p") ("raw:c_nzuimm5" "c_nzuimm5")) "c.srli_rv32 rd_rs1_p, c_nzuimm5")
   (instruction-info 'c.srai_rv32 'rv32_c 16 2 '("rd_rs1_p" "c_nzuimm5") '("rd_rs1_p" "c_nzuimm5") '((0 1 1) (13 15 4) (10 12 1)) '() (instruction-origin 'pseudo 'rv64_c 'c.srai) '(("rd_rs1_p" "rd_rs1_p") ("c_nzuimm5" "c_nzuimm5")) '(("raw:rd_rs1_p" "rd_rs1_p") ("raw:c_nzuimm5" "c_nzuimm5")) "c.srai_rv32 rd_rs1_p, c_nzuimm5")
   (instruction-info 'c.slli_rv32 'rv32_c 16 2 '("rd_rs1_n0" "c_nzuimm6lo") '("rd_rs1_n0" "c_nzuimm6lo") '((0 1 2) (12 15 0)) '() (instruction-origin 'pseudo 'rv64_c 'c.slli) '(("rd_rs1_n0" "rd_rs1_n0") ("c_nzuimm6lo" "c_nzuimm6lo")) '(("raw:rd_rs1_n0" "rd_rs1_n0") ("raw:c_nzuimm6lo" "c_nzuimm6lo")) "c.slli_rv32 rd_rs1_n0, c_nzuimm6lo")))

(provide
 rv32_c-instructions)
