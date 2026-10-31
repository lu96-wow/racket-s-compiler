#lang racket
;;; amd64/expand-pseudo/test.rkt

(require rackunit
         "rewrite.rkt")

(define (rw #:short-branches? [short? #f] . items)
  (rewrite-program items #:short-branches? short?))

(check-equal? (rw '(jmp (done))) '((jmp-near (done))))
(check-equal? (rw '(jmp (done)) #:short-branches? #t) '((jmp-short (done))))
(check-equal? (rw '(jcc e (done))) '((jcc-near e (done))))
(check-equal? (rw '(jcc e (done)) #:short-branches? #t) '((jcc-short e (done))))
(check-equal? (rw '(call (foo))) '((call-near (foo))))

(check-equal? (rw '(je (done))) '((jcc-near e (done))))
(check-equal? (rw '(jnz (done))) '((jcc-near ne (done))))
(check-equal? (rw '(jc (done))) '((jcc-near b (done))))
(check-equal? (rw '(jnc (done))) '((jcc-near ae (done))))

(check-equal? (rw '(li rax 1)) '((mov rax 1)))

(check-equal? (rw '(mov rax rbx) '(add rax 1))
              '((mov rax rbx) (add rax 1)))
(check-equal? (rw '(label main) '(ret))
              '((label main) (ret)))

(check-false (pseudo-leftover? '((jmp-near (x)) (jcc-near e (x)) (mov rax 1))))
(check-true (pseudo-leftover? '(jmp (x))))
(check-true (pseudo-leftover? '(je (x))))

(displayln "amd64 expand-pseudo tests: ok")

(check-equal? (rw '(li rax (data)))
              '((lea rax (b64 (base rip) (disp (data))))))
(check-equal? (rw '(li rax (+ (data) 8)))
              '((lea rax (b64 (base rip) (disp (+ (data) 8))))))
(check-exn exn:fail?
           (lambda () (rw '(li rax "not-an-address"))))
