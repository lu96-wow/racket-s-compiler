#lang racket/base

;; ============================================================
;; Shared numeric encoding limits
;;
;; This is the single definition of the supported target bit range.
;; It is used by:
;;   - runtime/lib/bit.rkt      (field placement)
;;   - binary-build/model.rkt   (source fixed-field validation)
;;
;; Instruction-width rules remain in binary-build/parcel.rkt because
;; they are a different kind of constraint.
;; ============================================================

(define max-target-bit-index 31)

(provide max-target-bit-index)
