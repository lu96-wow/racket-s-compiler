#lang racket
;;; amd64/relax/relax.rkt
;;;
;;; 分支松弛: short -> near，只增不减。
;;; 每轮重跑 layout，消费 needs-near request。

(require "../sexp.rkt"
         "../layout/layout.rkt")

(provide relax
         promote-short-branch
         needs-near?)

(define max-rounds 64)

(define (needs-near? request)
  (and (form? request) (eq? (car request) 'needs-near)))

(define (promote-short-branch item)
  (case (car item)
    [(jmp-short) (cons 'jmp-near (cdr item))]
    [(jcc-short) (cons 'jcc-near (cdr item))]
    [else item]))

(define (promote-items items near-indexes)
  (for/list ([item (in-list items)] [i (in-naturals)])
    (if (set-member? near-indexes i)
        (promote-short-branch item)
        item)))

(define (relax target program data-items spec)
  (define items
    (append (program->layout-items program) (as-items data-items)))
  (let loop ([items items] [round 0])
    (define measured (layout-items target items spec))
    (define requests (cdr (or (assq 'requests measured) '(requests))))
    (define near* (filter needs-near? requests))
    (cond
      [(or (null? near*) (>= round max-rounds)) measured]
      [else
       (define indexes
         (list->set (for/list ([r (in-list near*)]) (cadr r))))
       (define next (promote-items items indexes))
       (if (equal? next items)
           measured
           (loop next (add1 round)))])))

