#lang racket/base

;; ============================================================
;; Fixed-field bit access
;;
;; Shared build-time helper used by:
;;   - resolve.rkt   (pseudo/source fixed-field compatibility)
;;   - emit/metadata.rkt (instruction width via parcel.rkt)
;; ============================================================

(require racket/list
         "model.rkt")

(define (fixed-field-bit-value ff bit)
  (if (<= (fixed-field-lo ff) bit (fixed-field-hi ff))
      (bitwise-and
       (arithmetic-shift
        (fixed-field-value ff)
        (- (fixed-field-lo ff) bit))
       1)
      #f))

(define (fixed-fields-bit-value fixed-fields bit)
  (for/first ([ff (in-list fixed-fields)]
              #:when (<= (fixed-field-lo ff) bit (fixed-field-hi ff)))
    (fixed-field-bit-value ff bit)))

(provide fixed-field-bit-value
         fixed-fields-bit-value)
