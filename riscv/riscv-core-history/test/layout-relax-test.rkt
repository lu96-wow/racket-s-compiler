#lang racket
;;; test/layout-relax-test.rkt
;;;
;;; layout-relax：block 顺序、fallthrough、branch/jump、inline far、call-target、return。

(require rackunit
         "../layout/relax.rkt"
         "../layout/plan.rkt"
         "../layout/policy.rkt")

(define frame16
  '(frame
     (size 16)
     (header 16)
     (outgoing 0)
     (align 16)
     (slots)))

(define (machine-func scratch blocks)
  (append (list 'func '(main)
                frame16
                (cons 'scratch scratch)
                '(entry b0))
          blocks))

(define (make-plan order fallthrough)
  (layout-plan '(main) 'b0 order
               (for/hash ([pair (in-list fallthrough)])
                 (values (car pair) (cadr pair)))))

(define (items-of func plan [policy default-layout-policy])
  (layout-result-items (layout-func func plan #:policy policy)))

;; ---------------------------------------------------------------------------
;; branch / jump / return
;; ---------------------------------------------------------------------------

(test-case "branch falls through to else, branches to then"
  (define func
    (machine-func
     '()
     '((block b0
         (add (native x12) (native x10) (native x11))
         (term (branch (eq (native x12) 0) b2 b1)))
       (block b1
         (addi (native x12) (native x12) 1)
         (term (jump b2)))
       (block b2
         (term (return))))))
  (define plan (make-plan '(b0 b1 b2) '((b0 b1) (b1 b2))))
  (check-equal?
   (items-of func plan)
   '((label b0)
     (add (native x12) (native x10) (native x11))
     (beq b2 (native x12) (native x0))
     (label b1)
     (addi (native x12) (native x12) 1)
     (label b2)
     (jalr (native x0) (native x1) 0))))

(test-case "branch falls through to then, emits inverted branch"
  (define func
    (machine-func
     '()
     '((block b0
         (term (branch (eq (native x12) 0) b2 b1)))
       (block b2
         (term (return)))
       (block b1
         (term (return))))))
  (define plan (make-plan '(b0 b2 b1) '((b0 b2))))
  (check-equal?
   (items-of func plan)
   '((label b0)
     (bne b1 (native x12) (native x0))
     (label b2)
     (jalr (native x0) (native x1) 0)
     (label b1)
     (jalr (native x0) (native x1) 0))))

(test-case "branch with neither successor next emits branch + jump"
  (define func
    (machine-func
     '()
     '((block b0
         (term (branch (eq (native x12) 0) b2 b3)))
       (block b1
         (term (return)))
       (block b2
         (term (return)))
       (block b3
         (term (return))))))
  (define plan (make-plan '(b0 b1 b2 b3) '()))
  (check-equal?
   (items-of func plan)
   '((label b0)
     (beq b2 (native x12) (native x0))
     (jal (native x0) b3)
     (label b1)
     (jalr (native x0) (native x1) 0)
     (label b2)
     (jalr (native x0) (native x1) 0)
     (label b3)
     (jalr (native x0) (native x1) 0))))

(test-case "jump to next block disappears; jump elsewhere appears"
  (define func
    (machine-func
     '()
     '((block b0
         (term (jump b1)))
       (block b1
         (term (jump b2)))
       (block b2
         (term (return))))))
  (define plan (make-plan '(b0 b1 b2) '((b0 b1))))
  (check-equal?
   (items-of func plan)
   '((label b0)
     (label b1)
     (label b2)
     (jalr (native x0) (native x1) 0))))

(test-case "le maps to bge with swapped operands"
  (define func
    (machine-func
     '()
     '((block b0
         (term (branch (le (native x10) (native x11)) b1 b2)))
       (block b1
         (term (return)))
       (block b2
         (term (return))))))
  (define plan (make-plan '(b0 b2 b1) '((b0 b2))))
  (check-equal?
   (items-of func plan)
   '((label b0)
     (bge b1 (native x11) (native x10))
     (label b2)
     (jalr (native x0) (native x1) 0)
     (label b1)
     (jalr (native x0) (native x1) 0))))

(test-case "trap becomes ebreak"
  (define func
    (machine-func
     '()
     '((block b0
         (term (trap))))))
  (define plan (make-plan '(b0) '()))
  (check-equal? (items-of func plan)
                '((label b0)
                  (ebreak))))

;; ---------------------------------------------------------------------------
;; far branch / scratch
;; ---------------------------------------------------------------------------

(test-case "far branch is expanded to inverted branch + jump + skip label"
  (define big-body
    (for/list ([i (in-range 1100)])
      '(addi (native x5) (native x5) 1)))
  (define func
    (machine-func
     '()
     (list (list* 'block 'b0
                  (list '(term (branch (eq (native x12) 0) b2 b1))))
           (list* 'block 'b1
                  (append big-body (list '(term (return)))))
           '(block b2 (term (return))))))
  (define plan (make-plan '(b0 b1 b2) '((b0 b1))))
  (define items (items-of func plan))
  (check-equal? (take items 4)
                '((label b0)
                  (bne relax-far-0 (native x12) (native x0))
                  (jal (native x0) b2)
                  (label relax-far-0)))
  (check-true (and (member '(label b2) items) #t)))

(test-case "nonzero condition immediate uses scratch"
  (define func
    (machine-func
     '((native x5))
     '((block b0
         (term (branch (eq (native x12) 42) b1 b2)))
       (block b1
         (term (return)))
       (block b2
         (term (return))))))
  (define plan (make-plan '(b0 b1 b2) '((b0 b1))))
  (define result (layout-func func plan))
  (check-equal? (layout-result-scratch-request result) 1)
  (check-equal?
   (layout-result-items result)
   '((label b0)
     (addi (native x5) (native x0) 42)
     (bne b2 (native x12) (native x5))
     (label b1)
     (jalr (native x0) (native x1) 0)
     (label b2)
     (jalr (native x0) (native x1) 0))))

(test-case "nonzero condition immediate without scratch is an error"
  (define func
    (machine-func
     '()
     '((block b0
         (term (branch (eq (native x12) 42) b1 b2)))
       (block b1
         (term (return)))
       (block b2
         (term (return))))))
  (define plan (make-plan '(b0 b1 b2) '((b0 b1))))
  (check-exn #rx"not enough scratch"
             (lambda () (layout-func func plan))))

;; ---------------------------------------------------------------------------
;; call-target / errors
;; ---------------------------------------------------------------------------

(test-case "call-target stays symbolic with 8 bytes"
  (define func
    (machine-func
     '()
     '((block b0
         (call-target (global (f)))
         (term (return))))))
  (define plan (make-plan '(b0) '()))
  (check-equal?
   (items-of func plan)
   '((label b0)
     (call-target (global (f)))
     (jalr (native x0) (native x1) 0))))

(test-case "unlowered call is rejected"
  (define func
    (machine-func
     '()
     '((block b0
         (call (native x10) (global (f)))
         (term (return))))))
  (check-exn #rx"unlowered call"
             (lambda ()
               (layout-func func (make-plan '(b0) '())))))

(test-case "addr(global) is kept for program layout"
  (define func
    (machine-func
     '()
     '((block b0
         (addr (native x10) (global (d)))
         (term (return))))))
  (check-equal?
   (items-of func (make-plan '(b0) '()))
   '((label b0)
     (addr-global (native x10) (global (d)))
     (jalr (native x0) (native x1) 0))))

(test-case "return with operands is rejected"
  (define func
    (machine-func
     '()
     '((block b0
         (term (return (native x10)))))))
  (check-exn #rx"return still has operands"
             (lambda ()
               (layout-func func (make-plan '(b0) '())))))

(test-case "islands policy works when there are no far edges"
  (define func
    (machine-func
     '()
     '((block b0
         (term (return))))))
  (check-equal?
   (items-of func (make-plan '(b0) '())
             (make-layout-policy #:far-branch 'islands #:far-jump 'islands))
   '((label b0)
     (jalr (native x0) (native x1) 0))))

(test-case "mixed island/inline policy is explicitly rejected"
  (define func
    (machine-func
     '()
     '((block b0
         (term (return))))))
  (check-exn #rx"mixed island/inline policy"
             (lambda ()
               (layout-func func (make-plan '(b0) '())
                            #:policy (make-layout-policy
                                      #:far-branch 'islands
                                      #:far-jump 'inline)))))

(test-case "RVC policy is rejected"
  (define func
    (machine-func
     '()
     '((block b0
         (term (return))))))
  (check-exn #rx"RVC"
             (lambda ()
               (layout-func func (make-plan '(b0) '())
                            #:policy (make-layout-policy #:rvc? #t)))))
