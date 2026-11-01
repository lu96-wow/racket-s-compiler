#lang racket
;;; amd64/compiler/bind-labels/forms.rkt
;;;
;;; Bound-layout symbol s-expression.

(require "../../amd64-asm/shape.rkt")

(provide make-symbol symbol-entry?
         symbol-chain symbol-segment symbol-offset symbol-address)

(define (make-symbol chain segment offset address)
  (define path (normalize-path chain))
  (unless path (error 'make-symbol "symbol needs a non-empty chain: ~e" chain))
  (unless (symbol? segment)
    (error 'make-symbol "symbol segment must be a symbol: ~e" segment))
  (unless (exact-nonnegative-integer? offset)
    (error 'make-symbol "symbol offset must be non-negative: ~e" offset))
  (unless (exact-integer? address)
    (error 'make-symbol "symbol address must be an integer: ~e" address))
  (list 'symbol path segment offset address))

(define (symbol-entry? x)
  (and (form? x) (eq? (car x) 'symbol) (= 5 (length x)) #t))
(define (symbol-chain x) (cadr x))
(define (symbol-segment x) (caddr x))
(define (symbol-offset x) (cadddr x))
(define (symbol-address x) (list-ref x 4))
