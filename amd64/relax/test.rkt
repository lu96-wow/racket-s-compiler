#lang racket
;;; amd64/relax/test.rkt

(require rackunit
         "../analyze/analyze.rkt"
         "../layout/layout.rkt"
         "relax.rkt"
         "../target.rkt")

(define spec
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x201000) (align 16)))
    (place text (text))))

(define prog
  (analyze
   '((label text)
     (jcc-short e (done))
     (pad 200)
     (label done)
     (ret))
   '()))

(define before (layout-items (program->layout-items prog) spec))
(check-true (for/or ([r (in-list (cdr (assq 'requests before)))])
              (eq? (car r) 'needs-near)))

(define after (relax target-amd64 prog '() spec))
(check-equal? (cdr (assq 'requests after)) '())
(check-equal? (cdr (assq 'problems after)) '())
(define text (car (cdr (assq 'segments after))))
(define items (cdr (assq 'items (cdr text))))
(check-true (for/or ([e (in-list items)])
              (equal? (caddr e) '(jcc-near e (done)))))

(displayln "amd64 relax tests: ok")
