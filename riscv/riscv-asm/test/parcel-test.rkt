#lang racket/base

(require rackunit
         "../binary-build/parcel.rkt")

(define (lookup bits)
  (lambda (index)
    (and (< index (vector-length bits))
         (vector-ref bits index))))

(define (width bits)
  (parcel-length (lookup bits) "test-instruction"))

(check-equal? (width #(0 0)) 16)
(check-equal? (width #(1 0)) 16)
(check-equal? (width #(0 1)) 16)
(check-equal? (width #(0 1 1 1 1)) 16)

(check-equal? (width #(1 1 0 0 0)) 32)
(check-equal? (width #(1 1 1 0 0)) 32)
(check-equal? (width #(1 1 1 1 0)) 32)
(check-equal? (width #(1 1 #f #f 0)) 32)
(check-equal? (width #(1 1 #f #f 0 0 0)) 32)

(check-exn exn:fail? (lambda () (width #(1 1 1 1 1))))
(check-exn exn:fail? (lambda () (width #(1 1 1 1 1 0))))
(check-exn exn:fail? (lambda () (width #(1 1 1 1 1 0 0))))

(check-exn exn:fail? (lambda () (width #(#f 1))))
(check-exn exn:fail? (lambda () (width #(1 #f))))

(check-exn exn:fail? (lambda () (width #(1 1 1 #f #f))))
(check-exn exn:fail? (lambda () (width #(1 1 #f 1 #f))))
(check-exn exn:fail? (lambda () (width #(1 1 #f #f #f))))
