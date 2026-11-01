#lang racket
;;; amd64/amd64-help/test.rkt

(require rackunit
         "main.rkt")

(check-equal? (li->form 'rax 42) '(mov rax 42))
(check-equal? (li->form 'rax '(data))
              '(lea rax (b64 (base rip) (disp (data)))))
(check-true (positive? (li-size 'rax 42)))
(check-true (> (li-size 'rax '(data)) 0))

(check-equal? (canonical-cc 'jz) 'e)
(check-equal? (canonical-cc 'jnz) 'ne)
(check-equal? (canonical-cc 'jnc) 'ae)
(check-false (canonical-cc 'not-a-cc))
(check-true (jcc-alias? 'jz))
(check-false (jcc-alias? 'mov))

(check-equal? (jump-form '(done) #t) '(jmp-short (done)))
(check-equal? (jump-form '(done) #f) '(jmp-near (done)))
(check-equal? (branch-form 'e '(done) #t) '(jcc-short e (done)))
(check-equal? (branch-form 'e '(done) #f) '(jcc-near e (done)))
(check-equal? (branch-inverse 'e) 'ne)
(check-equal? (branch-inverse 'b) 'ae)

(check-true (fits-rel8? -128))
(check-false (fits-rel8? 128))
(check-true (fits-disp32? #xffffffff))
(check-false (fits-disp32? #x100000000))

(displayln "amd64-help tests: ok")
