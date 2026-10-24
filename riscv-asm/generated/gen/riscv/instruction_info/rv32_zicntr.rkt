#lang racket/base

(require "../../../lib/riscv/instruction_info/struct.rkt")

(define rv32_zicntr-instructions
  (list
   (instruction-info 'rdcycleh 'rv32_zicntr 32 4 '("rd") '("rd") '((15 19 0) (20 31 3200) (12 14 2) (2 6 28) (0 1 3)) '() "rdcycleh rd")
   (instruction-info 'rdtimeh 'rv32_zicntr 32 4 '("rd") '("rd") '((15 19 0) (20 31 3201) (12 14 2) (2 6 28) (0 1 3)) '() "rdtimeh rd")
   (instruction-info 'rdinstreth 'rv32_zicntr 32 4 '("rd") '("rd") '((15 19 0) (20 31 3202) (12 14 2) (2 6 28) (0 1 3)) '() "rdinstreth rd")))

(provide
 rv32_zicntr-instructions)
