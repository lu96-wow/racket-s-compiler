#lang racket
;;; amd64/compiler/layout/test.rkt

(require rackunit
         "../../amd64-asm/target.rkt"
         "../analyze/analyze.rkt"
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
  (layout-flat-items
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


;; ---------------------------------------------------------------------------
;; block-aware placement / validation
;; ---------------------------------------------------------------------------

(define (has-problem? out kind)
  (for/or ([p (in-list (cdr (assq 'problems out)))])
    (eq? (car p) kind)))

(define (code-seg name start end)
  (list 'segment (list 'name name) (list 'kind 'code)
        (list 'start start) (list 'end end) (list 'align 16)))

(define (data-seg name start end)
  (list 'segment (list 'name name) (list 'kind 'data)
        (list 'start start) (list 'end end) (list 'align 8)))

;; fallthrough into another segment is a layout problem
(define ft-prog
  (analyze '((label a) (jcc-near e b) (label b) (ret)) '()))
(define ft-spec
  (list (list 'segments (code-seg 't1 #x200000 #x200100)
              (code-seg 't2 #x201000 #x201100))
        '(place t1 (a))
        '(place t2 (b))))
(define ft-out (layout-program target-amd64 ft-prog '() ft-spec))
(check-true (has-problem? ft-out 'broken-fallthrough))

;; a block before any place is unplaced
(define unplaced-prog (analyze '((label x) (ret)) '()))
(define unplaced-spec
  (list (list 'segments (code-seg 'text #x200000 #x200100))
        '(place text (y))))
(define unplaced-out (layout-program target-amd64 unplaced-prog '() unplaced-spec))
(check-true (has-problem? unplaced-out 'unplaced-block))

;; (place text *) is the explicit wildcard
(define wildcard-spec
  (list (list 'segments (code-seg 'text #x200000 #x200100))
        '(place text *)))
(define wildcard-out (layout-program target-amd64 unplaced-prog '() wildcard-spec))
(check-equal? (cdr (assq 'problems wildcard-out)) '())
(check-equal? (cdr (assq 'anchors wildcard-out))
              '((anchor (x) text 0)))

;; segment start alignment and overlap are checked before measuring
(define misaligned-spec
  (list (list 'segments
              (list 'segment (list 'name 'text) (list 'kind 'code)
                    (list 'start #x200001) (list 'end #x200100) (list 'align 16)))
        '(place text (x))))
(define misaligned-out (layout-program target-amd64 unplaced-prog '() misaligned-spec))
(check-true (has-problem? misaligned-out 'segment-misaligned))

(define overlap-spec
  (list (list 'segments
              (code-seg 'a #x200000 #x201000)
              (code-seg 'b #x200800 #x202000))
        '(place a (x))))
(define overlap-out (layout-program target-amd64 unplaced-prog '() overlap-spec))
(check-true (has-problem? overlap-out 'segment-overlap))

;; data runs need a label and a place
(define empty-prog (analyze '() '()))
(define unlabeled-out
  (layout-program target-amd64 empty-prog '((value 8 1)) spec))
(check-true (has-problem? unlabeled-out 'unlabeled-run))

(define unplaced-data-out
  (layout-program target-amd64 empty-prog
                  '((label nowhere) (value 8 1))
                  (list (list 'segments (code-seg 'text #x200000 #x200100))
                        '(place text (text)))))
(check-true (has-problem? unplaced-data-out 'unplaced-data))

;; RIP-relative and absolute symbolic addresses are range-checked in layout
(define far-data-spec
  (list (list 'segments (code-seg 'text #x200000 #x201000)
              (data-seg 'data #x100000000 #x100001000))
        '(place text (text))
        '(place data (data))))

(define rip-prog
  (analyze '((label text)
             (mov rax (b64 (base rip) (disp (data))))
             (ret))
           '()))
(define rip-out
  (layout-program target-amd64 rip-prog
                  '((label data) (value 8 0))
                  far-data-spec))
(check-true (has-problem? rip-out 'rip-out-of-range))

(define abs-prog
  (analyze '((label text)
             (mov rax (b64 (disp (data))))
             (ret))
           '()))
(define abs-out
  (layout-program target-amd64 abs-prog
                  '((label data) (value 8 0))
                  far-data-spec))
(check-true (has-problem? abs-out 'absolute-out-of-range))

;; near branch overflow becomes a request, not a silent byte truncation
(define far-branch-prog
  (analyze '((label text)
             (jmp-near (data)))
           '()))
(define far-branch-out
  (layout-program target-amd64 far-branch-prog
                  '((label data) (value 8 0))
                  far-data-spec))
(check-true
 (for/or ([r (in-list (cdr (assq 'requests far-branch-out)))])
   (eq? (car r) 'needs-far)))
