#lang racket
;;; amd64/loko-compatibility/lower/test.rkt

(require rackunit
         "pseudo.rkt"
         "uses.rkt"
         "liveness.rkt"
         "allocate.rkt"
         "lower.rkt"
         "calls.rkt"
         "../../compiler/analyze/analyze.rkt")

;; ---------------------------------------------------------------------------
;; pseudo
;; ---------------------------------------------------------------------------

(check-true (pseudo-register? '(reg 0)))
(check-false (pseudo-register? '(reg -1)))
(check-false (pseudo-register? '(reg x)))
(check-equal? (pseudo-registers-in '(mov (reg 0) (b64 (disp (+ (reg 1) 8)))))
              '(0 1))

(define-values (sub missing)
  (substitute-pseudo-registers
   '(mov (reg 0) (b64 (disp (+ (reg 1) 8))))
   (hash 0 'rax 1 'rcx)))
(check-equal? sub '(mov rax (b64 (disp (+ rcx 8)))))
(check-equal? missing '())

(define-values (sub2 missing2)
  (substitute-pseudo-registers
   '(mov (reg 0) (reg 9))
   (hash 0 'rax)))
(check-equal? sub2 '(mov rax (reg 9)))
(check-equal? missing2 '(9))

;; ---------------------------------------------------------------------------
;; uses / sets
;; ---------------------------------------------------------------------------

(define (uses/sets inst)
  (define-values (u s) (instruction-uses/sets inst))
  (values u s))

(check-equal? (call-with-values (lambda () (uses/sets '(mov (reg 0) (reg 1)))) list)
              '((1) (0)))
(check-equal? (call-with-values (lambda () (uses/sets '(add (reg 0) (reg 1)))) list)
              '((0 1) (0)))
(check-equal? (call-with-values (lambda () (uses/sets '(cmp (reg 0) (reg 1)))) list)
              '((0 1) ()))
(check-equal? (call-with-values (lambda () (uses/sets '(push (reg 0)))) list)
              '((0) ()))
(check-equal? (call-with-values (lambda () (uses/sets '(pop (reg 0)))) list)
              '(() (0)))
(check-equal? (call-with-values (lambda () (uses/sets '(prefix lock (xadd (reg 0) (reg 1)))) ) list)
              '((0 1) (0 1)))

;; ---------------------------------------------------------------------------
;; liveness
;; ---------------------------------------------------------------------------

(define liveness-items
  '((label entry)
    (mov (reg 0) 1)
    (mov (reg 1) 2)
    (add (reg 0) (reg 1))
    (ret)))

(define lv (compute-liveness liveness-items))
(check-equal? (block-live-in lv 0) '())
(check-equal? (block-live-out lv 0) '())
(check-equal? (live-out-after lv 0 0) '(0))
(check-equal? (live-out-after lv 0 1) '(0 1))
(check-equal? (live-out-after lv 0 2) '())
(check-equal? (liveness-pseudos lv) '(0 1))

;; A value used in a later block is live out of the earlier block.
(define loop-items
  '((label entry)
    (mov (reg 0) 1)
    (jmp-near (label-head))
    (label loop)
    (add (reg 0) 1)
    (label label-head)
    (add (reg 0) 1)
    (ret)))

(define loop-lv (compute-liveness loop-items))
(check-not-false (member 0 (block-live-out loop-lv 0)))

;; ---------------------------------------------------------------------------
;; allocation
;; ---------------------------------------------------------------------------

(define alloc-items
  '((label entry)
    (mov (reg 0) 1)
    (mov (reg 1) 2)
    (add (reg 0) (reg 1))
    (mov (reg 2) (reg 0))
    (ret)))

(define alloc-lv (compute-liveness alloc-items))
(define alloc-result
  (allocate-pseudo-registers alloc-lv alloc-items #:available '(rax rcx)))
(check-equal? (allocation-result-uncolored alloc-result) '())
(check-equal? (sort (hash-values (allocation-result-allocation alloc-result)) symbol<?)
              '(rax rax rcx))
(check-true (not (equal? (hash-ref (allocation-result-allocation alloc-result) 0)
                         (hash-ref (allocation-result-allocation alloc-result) 1))))

(define tight-result
  (allocate-pseudo-registers alloc-lv alloc-items #:available '(rax)))
(check-true (pair? (allocation-result-uncolored tight-result)))

;; ---------------------------------------------------------------------------
;; lower
;; ---------------------------------------------------------------------------

(define explicit
  (lower-program-items '((mov (reg 0) (reg 1)))
                       #:allocation (hash 0 'rax 1 'rcx)))
(check-equal? (lower-result-items explicit) '((mov rax rcx)))
(check-equal? (lower-result-allocation explicit) '((0 . rax) (1 . rcx)))
(check-equal? (lower-result-problems explicit) '())

(define alist
  (lower-program-items '((mov (reg 0) (reg 1)))
                       #:allocation '((0 . rax) (1 . rcx))))
(check-equal? (lower-result-items alist) '((mov rax rcx)))

(define automatic
  (lower-program-items alloc-items #:available '(rax rcx)))
(check-equal? (lower-result-problems automatic) '())
(check-false
 (for/or ([item (in-list (lower-result-items automatic))])
   (pair? (pseudo-registers-in item))))

(define unallocated
  (lower-program-items '((mov (reg 0) (reg 1)))
                       #:allocation (hash 0 'rax)))
(check-equal? (lower-result-items unallocated) '((mov rax (reg 1))))
(check-equal? (lower-result-problems unallocated)
              '((problem unallocated-pseudo 1)))

;; ---------------------------------------------------------------------------
;; call save / restore
;; ---------------------------------------------------------------------------

(define call-items
  '((label entry)
    (mov (reg 0) 1)
    (comment save-live-registers)
    (call-near (f))
    (comment liveness-information)
    (comment restore-live-registers)
    (add (reg 0) 1)
    (ret)))

(define call-lv (compute-liveness call-items))
(check-equal? (call-crossing-pseudos call-lv call-items) '(0))

(define expanded (expand-call-saves call-items))
(check-equal? (call-save-result-problems expanded) '())
(check-equal? (call-save-result-fresh-count expanded) 1)
(check-equal? (call-save-result-items expanded)
              '((label entry)
                (mov (reg 0) 1)
                (mov (reg 1) (reg 0))
                (call-near (f))
                (comment liveness-information)
                (mov (reg 0) (reg 1))
                (add (reg 0) 1)
                (ret)))

(define expanded-lv (compute-liveness (call-save-result-items expanded)))
(check-equal? (call-crossing-pseudos expanded-lv (call-save-result-items expanded))
              '(1))

(check-true
 (for/or ([p (in-list
              (call-save-result-problems
               (expand-call-saves '((comment restore-live-registers)))))])
   (equal? (cadr p) 'restore-without-save)))

(displayln "amd64 loko-lower tests: ok")
