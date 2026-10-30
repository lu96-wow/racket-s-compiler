#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_c_zicfiss-instructions
  (list
   (instruction-info 'c.sspush.x1 'rv_c_zicfiss 16 2 '() '() '((0 1 1) (2 6 0) (7 11 1) (12 12 0) (13 15 3)) '() (instruction-origin 'pseudo 'rv_zcmop 'c.mop.N) '() '() "c.sspush.x1")
   (instruction-info 'c.sspopchk.x5 'rv_c_zicfiss 16 2 '() '() '((0 1 1) (2 6 0) (7 11 5) (12 12 0) (13 15 3)) '() (instruction-origin 'pseudo 'rv_zcmop 'c.mop.N) '() '() "c.sspopchk.x5")))

(provide
 rv_c_zicfiss-instructions)
