#lang racket
;;; amd64/test/flow-test.rkt

(require rackunit
         "../flow/flow.rkt"
         "../target.rkt")

(define spec
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x201000) (align 16))
     (segment (name data) (kind data) (start #x300000) (end #x301000) (align 8)))
    (place text (text))
    (place data (data))))

(define build
  (compile
   target-amd64
   (list (cons 'rich-data '((label data) (b64 #x1234)))
         (cons 'program-items
               '((label text)
                 (mov rax rbx)
                 (jmp-near (done))
                 (label done)
                 (ret)))
         (cons 'layout-spec spec))))

(check-equal? build
              '(build
                (segment (name text) (kind code) (start #x200000) (size 4)
                         (bytes #"H\x89\xd8\xc3"))
                (segment (name data) (kind data) (start #x300000) (size 8)
                         (bytes #"\x34\x12\x00\x00\x00\x00\x00\x00"))))

(displayln "amd64 flow tests: ok")

;; short branch promoted by relax when the target is out of rel8 range
(define spec2
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x201000) (align 16)))
    (place text (text))))
(define build2
  (compile
   target-amd64
   (list (cons 'rich-data '())
         (cons 'program-items
               '((label text)
                 (jcc e (done))
                 (pad 200)
                 (label done)
                 (ret)))
         (cons 'layout-spec spec2))))
(define text2 (cadr build2))
(check-equal? (cadr (assq 'size (cdr text2))) 207)
(check-equal? (subbytes (cadr (assq 'bytes (cdr text2))) 0 2) (bytes #x0f #x84))
