#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv_zks-instructions
  (list
   (instruction-info 'rol 'rv_zks 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 1) (2 6 12) (0 1 3)) '() "rol rd, rs1, rs2")
   (instruction-info 'ror 'rv_zks 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 48) (12 14 5) (2 6 12) (0 1 3)) '() "ror rd, rs1, rs2")
   (instruction-info 'andn 'rv_zks 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 7) (2 6 12) (0 1 3)) '() "andn rd, rs1, rs2")
   (instruction-info 'orn 'rv_zks 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 6) (2 6 12) (0 1 3)) '() "orn rd, rs1, rs2")
   (instruction-info 'xnor 'rv_zks 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 4) (2 6 12) (0 1 3)) '() "xnor rd, rs1, rs2")
   (instruction-info 'pack 'rv_zks 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 4) (12 14 4) (2 6 12) (0 1 3)) '() "pack rd, rs1, rs2")
   (instruction-info 'packh 'rv_zks 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 4) (12 14 7) (2 6 12) (0 1 3)) '() "packh rd, rs1, rs2")
   (instruction-info 'clmul 'rv_zks 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 1) (2 6 12) (0 1 3)) '() "clmul rd, rs1, rs2")
   (instruction-info 'clmulh 'rv_zks 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 5) (12 14 3) (2 6 12) (0 1 3)) '() "clmulh rd, rs1, rs2")
   (instruction-info 'xperm4 'rv_zks 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 20) (12 14 2) (2 6 12) (0 1 3)) '() "xperm4 rd, rs1, rs2")
   (instruction-info 'xperm8 'rv_zks 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 20) (12 14 4) (2 6 12) (0 1 3)) '() "xperm8 rd, rs1, rs2")
   (instruction-info 'sm4ed 'rv_zks 32 4 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 24) (12 14 0) (0 6 51)) '() "sm4ed rd, rs1, rs2, bs")
   (instruction-info 'sm4ks 'rv_zks 32 4 '("rd" "rs1" "rs2" "bs") '("rd" "rs1" "rs2" "bs") '((25 29 26) (12 14 0) (0 6 51)) '() "sm4ks rd, rs1, rs2, bs")
   (instruction-info 'sm3p0 'rv_zks 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 8) (12 14 1) (0 6 19)) '() "sm3p0 rd, rs1")
   (instruction-info 'sm3p1 'rv_zks 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 9) (12 14 1) (0 6 19)) '() "sm3p1 rd, rs1")
   (instruction-info 'brev8 'rv_zks 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 1671) (12 14 5) (2 6 4) (0 1 3)) '() "brev8 rd, rs1")))

(provide
 rv_zks-instructions)
