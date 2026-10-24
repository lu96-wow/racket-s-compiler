#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv32_c-instructions
  (list
   (instruction-info 'c.jal 'rv32_c 16 2 '("c_imm12") '("c_imm12") '((0 1 1) (13 15 1)) '() "c.jal c_imm12")
   (instruction-info 'c.srli 'rv32_c 16 2 '("rd_rs1_p" "c_nzuimm5") '("rd_rs1_p" "c_nzuimm5") '((0 1 1) (13 15 4) (10 12 0)) '() "c.srli rd_rs1_p, c_nzuimm5")
   (instruction-info 'c.srai 'rv32_c 16 2 '("rd_rs1_p" "c_nzuimm5") '("rd_rs1_p" "c_nzuimm5") '((0 1 1) (13 15 4) (10 12 1)) '() "c.srai rd_rs1_p, c_nzuimm5")
   (instruction-info 'c.slli 'rv32_c 16 2 '("rd_rs1_n0" "c_nzuimm6lo") '("rd_rs1_n0" "c_nzuimm6lo") '((0 1 2) (12 15 0)) '() "c.slli rd_rs1_n0, c_nzuimm6lo")
   (instruction-info 'c.srli_rv32 'rv32_c 16 2 '("rd_rs1_p" "c_nzuimm5") '("rd_rs1_p" "c_nzuimm5") '((0 1 1) (13 15 4) (10 12 0)) '() "c.srli_rv32 rd_rs1_p, c_nzuimm5")
   (instruction-info 'c.srai_rv32 'rv32_c 16 2 '("rd_rs1_p" "c_nzuimm5") '("rd_rs1_p" "c_nzuimm5") '((0 1 1) (13 15 4) (10 12 1)) '() "c.srai_rv32 rd_rs1_p, c_nzuimm5")
   (instruction-info 'c.slli_rv32 'rv32_c 16 2 '("rd_rs1_n0" "c_nzuimm6lo") '("rd_rs1_n0" "c_nzuimm6lo") '((0 1 2) (12 15 0)) '() "c.slli_rv32 rd_rs1_n0, c_nzuimm6lo")))

(provide
 rv32_c-instructions)
