#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv64_i-instructions
  (list
   (instruction-info 'lwu 'rv64_i 32 4 '("rd" "rs1" "imm12") '("rd" "rs1" "imm12") '((12 14 6) (2 6 0) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("imm12" "imm12")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:imm12" "imm12")) "lwu rd, rs1, imm12")
   (instruction-info 'ld 'rv64_i 32 4 '("rd" "rs1" "imm12") '("rd" "rs1" "imm12") '((12 14 3) (2 6 0) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("imm12" "imm12")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:imm12" "imm12")) "ld rd, rs1, imm12")
   (instruction-info 'sd 'rv64_i 32 4 '("simm12" "rs1" "rs2") '("imm12hi" "rs1" "rs2" "imm12lo") '((12 14 3) (2 6 8) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("imm12hi" "imm12hi") ("rs1" "rs1") ("rs2" "rs2") ("imm12lo" "imm12lo")) '(("rebuilt:simm12" "simm12") ("raw:rs1" "rs1") ("raw:rs2" "rs2") ("rebuilt:simm12" "simm12")) "sd simm12, rs1, rs2")
   (instruction-info 'slli 'rv64_i 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 0) (12 14 1) (2 6 4) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("shamtd" "shamtd")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtd" "shamtd")) "slli rd, rs1, shamtd")
   (instruction-info 'srli 'rv64_i 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 0) (12 14 5) (2 6 4) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("shamtd" "shamtd")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtd" "shamtd")) "srli rd, rs1, shamtd")
   (instruction-info 'srai 'rv64_i 32 4 '("rd" "rs1" "shamtd") '("rd" "rs1" "shamtd") '((26 31 16) (12 14 5) (2 6 4) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("shamtd" "shamtd")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtd" "shamtd")) "srai rd, rs1, shamtd")
   (instruction-info 'addiw 'rv64_i 32 4 '("rd" "rs1" "imm12") '("rd" "rs1" "imm12") '((12 14 0) (2 6 6) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("imm12" "imm12")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:imm12" "imm12")) "addiw rd, rs1, imm12")
   (instruction-info 'slliw 'rv64_i 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 0) (12 14 1) (2 6 6) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "slliw rd, rs1, shamtw")
   (instruction-info 'srliw 'rv64_i 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 0) (12 14 5) (2 6 6) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "srliw rd, rs1, shamtw")
   (instruction-info 'sraiw 'rv64_i 32 4 '("rd" "rs1" "shamtw") '("rd" "rs1" "shamtw") '((25 31 32) (12 14 5) (2 6 6) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("shamtw" "shamtw")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:shamtw" "shamtw")) "sraiw rd, rs1, shamtw")
   (instruction-info 'addw 'rv64_i 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 0) (12 14 0) (2 6 14) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "addw rd, rs1, rs2")
   (instruction-info 'subw 'rv64_i 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 0) (2 6 14) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "subw rd, rs1, rs2")
   (instruction-info 'sllw 'rv64_i 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 0) (12 14 1) (2 6 14) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "sllw rd, rs1, rs2")
   (instruction-info 'srlw 'rv64_i 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 0) (12 14 5) (2 6 14) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "srlw rd, rs1, rs2")
   (instruction-info 'sraw 'rv64_i 32 4 '("rd" "rs1" "rs2") '("rd" "rs1" "rs2") '((25 31 32) (12 14 5) (2 6 14) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("rs2" "rs2")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:rs2" "rs2")) "sraw rd, rs1, rs2")
   (instruction-info 'sext.w 'rv64_i 32 4 '("rd" "rs1") '("rd" "rs1") '((20 31 0) (12 14 0) (2 6 6) (0 1 3)) '() (instruction-origin 'pseudo 'rv64_i 'addiw) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "sext.w rd, rs1")))

(provide
 rv64_i-instructions)
