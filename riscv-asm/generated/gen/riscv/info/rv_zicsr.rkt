#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zicsr-instructions
  (list
   (instruction-info 'csrrw 'rv_zicsr 32 4 '("rd" "rs1" "csr") '("rd" "rs1" "csr") '((12 14 1) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("csr" "csr")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:csr" "csr")) "csrrw rd, rs1, csr")
   (instruction-info 'csrrs 'rv_zicsr 32 4 '("rd" "rs1" "csr") '("rd" "rs1" "csr") '((12 14 2) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("csr" "csr")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:csr" "csr")) "csrrs rd, rs1, csr")
   (instruction-info 'csrrc 'rv_zicsr 32 4 '("rd" "rs1" "csr") '("rd" "rs1" "csr") '((12 14 3) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1") ("csr" "csr")) '(("raw:rd" "rd") ("raw:rs1" "rs1") ("raw:csr" "csr")) "csrrc rd, rs1, csr")
   (instruction-info 'csrrwi 'rv_zicsr 32 4 '("rd" "csr" "zimm5") '("rd" "csr" "zimm5") '((12 14 5) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("csr" "csr") ("zimm5" "zimm5")) '(("raw:rd" "rd") ("raw:csr" "csr") ("raw:zimm5" "zimm5")) "csrrwi rd, csr, zimm5")
   (instruction-info 'csrrsi 'rv_zicsr 32 4 '("rd" "csr" "zimm5") '("rd" "csr" "zimm5") '((12 14 6) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("csr" "csr") ("zimm5" "zimm5")) '(("raw:rd" "rd") ("raw:csr" "csr") ("raw:zimm5" "zimm5")) "csrrsi rd, csr, zimm5")
   (instruction-info 'csrrci 'rv_zicsr 32 4 '("rd" "csr" "zimm5") '("rd" "csr" "zimm5") '((12 14 7) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("csr" "csr") ("zimm5" "zimm5")) '(("raw:rd" "rd") ("raw:csr" "csr") ("raw:zimm5" "zimm5")) "csrrci rd, csr, zimm5")
   (instruction-info 'csrr 'rv_zicsr 32 4 '("rd" "csr") '("rd" "csr") '((15 19 0) (12 14 2) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zicsr 'csrrs) '(("rd" "rd") ("csr" "csr")) '(("raw:rd" "rd") ("raw:csr" "csr")) "csrr rd, csr")
   (instruction-info 'csrw 'rv_zicsr 32 4 '("rs1" "csr") '("rs1" "csr") '((12 14 1) (7 11 0) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zicsr 'csrrw) '(("rs1" "rs1") ("csr" "csr")) '(("raw:rs1" "rs1") ("raw:csr" "csr")) "csrw rs1, csr")
   (instruction-info 'csrs 'rv_zicsr 32 4 '("rs1" "csr") '("rs1" "csr") '((12 14 2) (7 11 0) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zicsr 'csrrs) '(("rs1" "rs1") ("csr" "csr")) '(("raw:rs1" "rs1") ("raw:csr" "csr")) "csrs rs1, csr")
   (instruction-info 'csrc 'rv_zicsr 32 4 '("rs1" "csr") '("rs1" "csr") '((12 14 3) (7 11 0) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zicsr 'csrrc) '(("rs1" "rs1") ("csr" "csr")) '(("raw:rs1" "rs1") ("raw:csr" "csr")) "csrc rs1, csr")
   (instruction-info 'csrwi 'rv_zicsr 32 4 '("csr" "zimm5") '("csr" "zimm5") '((12 14 5) (7 11 0) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zicsr 'csrrwi) '(("csr" "csr") ("zimm5" "zimm5")) '(("raw:csr" "csr") ("raw:zimm5" "zimm5")) "csrwi csr, zimm5")
   (instruction-info 'csrsi 'rv_zicsr 32 4 '("csr" "zimm5") '("csr" "zimm5") '((12 14 6) (7 11 0) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zicsr 'csrrsi) '(("csr" "csr") ("zimm5" "zimm5")) '(("raw:csr" "csr") ("raw:zimm5" "zimm5")) "csrsi csr, zimm5")
   (instruction-info 'csrci 'rv_zicsr 32 4 '("csr" "zimm5") '("csr" "zimm5") '((12 14 7) (7 11 0) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zicsr 'csrrci) '(("csr" "csr") ("zimm5" "zimm5")) '(("raw:csr" "csr") ("raw:zimm5" "zimm5")) "csrci csr, zimm5")))

(provide
 rv_zicsr-instructions)
