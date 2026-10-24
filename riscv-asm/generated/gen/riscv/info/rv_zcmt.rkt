#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_zcmt-instructions
  (list
   (instruction-info 'cm.jalt 'rv_zcmt 16 2 '("c_index") '("c_index") '((0 1 2) (13 15 5) (10 12 0)) '() (instruction-origin 'standard #f #f) '(("c_index" "c_index")) '(("raw:c_index" "c_index")) "cm.jalt c_index")))

(provide
 rv_zcmt-instructions)
