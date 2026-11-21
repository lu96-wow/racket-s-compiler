#lang racket
;;; test/call-plan-test.rkt
;;;
;;; call-plan：最大参数、outgoing size、scratch demand。

(require rackunit
         "../ir/call-plan.rkt")

(define (machine-func-with-ops ops term)
  (list 'func '(main)
        '(frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
        '(scratch (native x5))
        '(entry b0)
        (list* 'block 'b0 (append ops (list term)))))

(test-case "no call"
  (define func
    (machine-func-with-ops
     '()
     '(term (return (native x10)))))
  (define plan (plan-calls func))
  (check-equal? (call-plan-max-args plan) 0)
  (check-equal? (call-plan-outgoing-size plan) 0)
  (check-equal? (call-plan-scratch-demand plan) 1))

(test-case "calls take the maximum argument count"
  (define func
    (machine-func-with-ops
     '((call (native x10) (global (f)) (native x11) (native x12))
       (call (native x10) (global (g)) (native x11)))
     '(term (return (native x10)))))
  (define plan (plan-calls func))
  (check-equal? (call-plan-max-args plan) 2)
  (check-equal? (call-plan-outgoing-size plan) 16)
  (check-equal? (call-plan-scratch-demand plan) 2))

(test-case "rv32 outgoing size uses 4-byte words"
  (define func
    (machine-func-with-ops
     '((call (native x10) (global (f)) (native x11) (native x12)))
     '(term (return (native x10)))))
  (define plan (plan-calls func #:xlen 32))
  (check-equal? (call-plan-max-args plan) 2)
  (check-equal? (call-plan-outgoing-size plan) 16))

(test-case "more than one return value is rejected"
  (define func
    (machine-func-with-ops
     '()
     '(term (return (native x10) (native x11)))))
  (check-exn #rx"at most one return value"
             (lambda () (plan-calls func))))
