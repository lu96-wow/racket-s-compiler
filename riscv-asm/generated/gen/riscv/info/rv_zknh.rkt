#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zknh-instructions
  (list
   (instruction-info 'sha256sum0 'rv_zknh 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 0) (12 14 1) (0 6 19)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "sha256sum0 rd, rs1")
   (instruction-info 'sha256sum1 'rv_zknh 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 1) (12 14 1) (0 6 19)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "sha256sum1 rd, rs1")
   (instruction-info 'sha256sig0 'rv_zknh 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 2) (12 14 1) (0 6 19)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "sha256sig0 rd, rs1")
   (instruction-info 'sha256sig1 'rv_zknh 32 4 '("rd" "rs1") '("rd" "rs1") '((30 31 0) (25 29 8) (20 24 3) (12 14 1) (0 6 19)) '() (instruction-origin 'standard #f #f) '(("rd" "rd") ("rs1" "rs1")) '(("raw:rd" "rd") ("raw:rs1" "rs1")) "sha256sig1 rd, rs1")))

(provide
 rv_zknh-instructions)
