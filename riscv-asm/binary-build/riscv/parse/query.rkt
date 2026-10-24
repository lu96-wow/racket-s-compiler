#lang racket/base

(require "struct.rkt"
         "../parcel.rkt")

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

;; 指令宽度完全交给 parcel 规则（parcel.rkt）；
;; 这里只负责从 fixed fields 里取位。位没固定时由规则报错，不做猜测。
(define (instruction-width idef)
  (parcel-length
   (lambda (bit)
     (fixed-bit-value (instruction-def-fixed-fields idef) bit))
   (instruction-def-name idef)))

(provide fixed-bit-value
         instruction-width)
