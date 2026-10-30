#lang racket/base

(require rackunit
         racket/list
         "../base/register.rkt")

;; ------------------------------------------------------------
;; tables
;; ------------------------------------------------------------

(check-equal? (length x-registers) 32)
(check-equal? (car x-registers) 'x0)
(check-equal? (last x-registers) 'x31)
(check-equal? (length (remove-duplicates x-registers))
              (length x-registers))

(check-equal? (length (remove-duplicates (map car abi-registers)))
              (length abi-registers))

(for ([entry (in-list abi-registers)])
  (check-true (x-register? (cdr entry)))
  (check-equal? (register->number (car entry))
                (register->number (cdr entry))))

;; ------------------------------------------------------------
;; classification
;; ------------------------------------------------------------

(check-true (x-register? 'x0))
(check-true (x-register? 'x31))
(check-false (x-register? 'x32))
(check-false (x-register? "x0"))

(check-true (abi-register? 'zero))
(check-true (abi-register? 'fp))
(check-false (abi-register? 'x0))
(check-false (abi-register? 'foo))

(check-true (register? 'a0))
(check-true (register? 'x10))
(check-true (register? 10))
(check-false (register? 32))
(check-false (register? -1))
(check-false (register? 'foo))

;; ------------------------------------------------------------
;; normalization
;; ------------------------------------------------------------

(check-equal? (register->number 'x0) 0)
(check-equal? (register->number 'zero) 0)
(check-equal? (register->number 'x10) 10)
(check-equal? (register->number 'a0) 10)
(check-equal? (register->number 10) 10)
(check-equal? (register->number 'fp) 8)
(check-equal? (register->number 's0) 8)
(check-false (register->number 'foo))
(check-false (register->number 32))

(check-equal? (register-x-name 'zero) 'x0)
(check-equal? (register-x-name 'a0) 'x10)
(check-equal? (register-x-name 'fp) 'x8)
(check-equal? (register-x-name 31) 'x31)
(check-false (register-x-name 'foo))

(check-equal? (register-abi-name 'x0) 'zero)
(check-equal? (register-abi-name 'x8) 's0)
(check-equal? (register-abi-name 'x10) 'a0)
(check-equal? (register-abi-name 'a0) 'a0)

(check-equal? (register-abi-names 'x8) '(s0 fp))
(check-equal? (register-abi-names 'a0) '(a0))
(check-equal? (register-abi-names 'foo) '())

;; ------------------------------------------------------------
;; comparison
;; ------------------------------------------------------------

(check-true (same-register? 'a0 'x10))
(check-true (same-register? 's0 'fp))
(check-true (same-register? 10 'a0))
(check-false (same-register? 'a0 'a1))

(check-true (zero-register? 'zero))
(check-true (zero-register? 'x0))
(check-true (zero-register? 0))
(check-false (zero-register? 'a0))

(check-true (nonzero-register? 'a0))
(check-false (nonzero-register? 'zero))
(check-false (nonzero-register? 'foo))

(check-true (compressed-prime-register? 's0))
(check-true (compressed-prime-register? 'a0))
(check-true (compressed-prime-register? 15))
(check-false (compressed-prime-register? 'x7))
(check-false (compressed-prime-register? 'x16))
(check-true (compressed-branch-register? 'a1))
(check-false (compressed-branch-register? 's2))
