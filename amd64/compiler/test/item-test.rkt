#lang racket
;;; amd64/compiler/test/item-test.rkt

(require rackunit
         "../item.rkt")

(check-equal? (make-label 'main) '(label main))
(check-equal? (make-label '(a b)) '(label a b))
(check-equal? (label-chain (make-label '(a b))) '(a b))

(check-equal? (make-comment 'liveness 'x) '(comment liveness x))
(check-true (comment-form? (make-comment 'x)))

(check-equal? (make-align 16) '(align 16))
(check-true (align-form? (make-align 16)))
(check-equal? (align-value (make-align 16)) 16)
(check-exn exn:fail? (lambda () (make-align 0)))

(check-equal? (make-pad 8) '(pad 8))
(check-true (pad-form? (make-pad 8)))
(check-equal? (pad-size (make-pad 8)) 8)
(check-exn exn:fail? (lambda () (make-pad -1)))

(check-equal? (make-bytes-item '(1 2 3)) '(bytes 1 2 3))
(check-true (bytes-form? (make-bytes-item '(1 2 3))))
(check-equal? (bytes-content (make-bytes-item '(1 2 3))) '(1 2 3))
(check-exn exn:fail? (lambda () (make-bytes-item '(1 300))))

(check-equal? (make-fill 4 0) '(fill 4 0))
(check-true (fill-form? (make-fill 4 0)))
(check-equal? (fill-size (make-fill 4 0)) 4)
(check-equal? (fill-byte (make-fill 4 0)) 0)
(check-exn exn:fail? (lambda () (make-fill -1 0)))
(check-exn exn:fail? (lambda () (make-fill 1 256)))

(check-equal? (make-value 8 '(data)) '(value 8 (data)))
(check-equal? (make-value 4 42) '(value 4 42))
(check-true (value-form? (make-value 4 42)))
(check-equal? (value-payload (make-value 4 42)) 42)
(check-exn exn:fail? (lambda () (make-value 3 0)))
(check-exn exn:fail? (lambda () (make-value 4 "bad")))

(check-equal? (make-reserve 32) '(reserve 32))
(check-true (reserve-form? (make-reserve 32)))
(check-equal? (reserve-size (make-reserve 32)) 32)
(check-exn exn:fail? (lambda () (make-reserve -1)))

(displayln "amd64 item tests: ok")
