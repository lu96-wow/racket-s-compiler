#lang racket/base

(require rackunit
         racket/list
         "../generated/lib/info/struct.rkt"
         "../generated/lib/info/query.rkt"
         "../generated/lib/info/lookup.rkt")

(for ([ext (in-list (instruction-info-extensions))])
  (for ([info (in-list (extension-instruction-info ext))])
    (define name (instruction-info-name info))
    (define width (info-width info))
    (check-not-false (memv width '(16 32))
                     (format "~a/~a: width ~a" ext name width))
    (check-equal? (info-size info) (quotient width 8)
                  (format "~a/~a: size" ext name))))
