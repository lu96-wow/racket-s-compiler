#lang racket
;;; amd64/layout/test.rkt

(require rackunit
         "../target.rkt"
         "layout.rkt"
         "forms.rkt")

(check-equal? (item-size '(value 8 1)) 8)
(check-equal? (item-size '(pad 5)) 5)
(check-equal? (item-size '(comment liveness)) 0)
(check-equal? (item-size '(align 16)) #f)
(check-equal? (item-size '(mov rax rbx)) 3)
(check-equal? (item-size '(jmp-near (done))) 5)
(check-equal? (align-pad #x200003 8) 5)
(check-equal? (align-pad #x200000 16) 0)

(define spec
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x200100) (align 16))
     (segment (name data) (kind data) (start #x300000) (end #x300100) (align 8)))
    (place text (text))
    (place data (data))))

(define out
  (layout-items
   target-amd64
   '((label text)
     (align 4)
     (mov rax rbx)
     (jmp-near (done))
     (label done)
     (ret)
     (label data)
     (value 8 #x1234))
   spec))

(check-equal? (cdr (assq 'problems out)) '())
(check-equal? (cdr (assq 'anchors out))
              '((anchor (text) text 0)
                (anchor (done) text 8)
                (anchor (data) data 0)))

(define text
  (car (cdr (assq 'segments out))))
(define text-fields (cdr text))
(define items (cdr (assq 'items text-fields)))
(check-equal? (map car items) '(offset offset offset offset))
(check-equal? (map cadr items) '(0 0 3 8))
(check-equal? (cadr (assq 'size text-fields)) 9)

(displayln "amd64 layout tests: ok")
