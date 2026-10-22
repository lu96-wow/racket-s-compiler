#lang racket/base

(require "struct.rkt")

;; ============================================================
;; 固定位段查询
;; ============================================================

(define (fixed-bit-value fixed-fields bit)
  (for/first ([ff (in-list fixed-fields)]
              #:when (<= (fixed-field-lo ff) bit (fixed-field-hi ff)))
    (bitwise-and
     (arithmetic-shift (fixed-field-value ff)
                       (- (- bit (fixed-field-lo ff))))
     1)))

(define (instruction-width idef)
  (define fixed-fields (instruction-def-fixed-fields idef))
  (define b0 (fixed-bit-value fixed-fields 0))
  (define b1 (fixed-bit-value fixed-fields 1))
  (cond
    [(and b0 b1)
     (if (and (= b0 1) (= b1 1)) 32 16)]
    [else 32]))

(provide fixed-bit-value
         instruction-width)
