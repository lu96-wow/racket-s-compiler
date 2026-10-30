#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zicntr-instructions
  (list
   (instruction-info 'rdcycle 'rv_zicntr 32 4 '("rd") '("rd") '((15 19 0) (20 31 3072) (12 14 2) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zicsr 'csrrs) '(("rd" "rd")) '(("raw:rd" "rd")) "rdcycle rd")
   (instruction-info 'rdtime 'rv_zicntr 32 4 '("rd") '("rd") '((15 19 0) (20 31 3073) (12 14 2) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zicsr 'csrrs) '(("rd" "rd")) '(("raw:rd" "rd")) "rdtime rd")
   (instruction-info 'rdinstret 'rv_zicntr 32 4 '("rd") '("rd") '((15 19 0) (20 31 3074) (12 14 2) (2 6 28) (0 1 3)) '() (instruction-origin 'pseudo 'rv_zicsr 'csrrs) '(("rd" "rd")) '(("raw:rd" "rd")) "rdinstret rd")))

(provide
 rv_zicntr-instructions)
