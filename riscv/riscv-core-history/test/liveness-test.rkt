#lang racket
;;; test/liveness-test.rkt
;;;
;;; def-use 和 live-in / live-out。只测 virtual IR。

(require rackunit
         "../core/sexp.rkt"
         "../ir/liveness.rkt"
         "../examples/minimal.rkt"
         "../examples/branch.rkt")

(define (block-live lv block)
  (list (set->list (hash-ref (liveness-live-in lv) block))
        (set->list (hash-ref (liveness-live-out lv) block))))

(define (instruction-summary lv block)
  (for/list ([ins (in-list (hash-ref (liveness-instructions lv) block))])
    (list (car (instruction-form ins))
          (set->list (instruction-live-before ins))
          (set->list (instruction-live-after ins)))))

;; ---------------------------------------------------------------------------
;; def-use
;; ---------------------------------------------------------------------------

(test-case "def-use for common virtual ops"
  (check-equal? (call-with-values
                 (lambda () (op-def-use '(add ($ t) ($ a) ($ b))))
                 list)
                '((($ t)) (($ a) ($ b))))
  (check-equal? (call-with-values
                 (lambda () (op-def-use '(const ($ t) 7)))
                 list)
                '((($ t)) ()))
  (check-equal? (call-with-values
                 (lambda () (op-def-use '(copy ($ t) ($ a))))
                 list)
                '((($ t)) (($ a))))
  (check-equal? (call-with-values
                 (lambda () (op-def-use '(load ($ t) ($ p) 0 (b64))))
                 list)
                '((($ t)) (($ p))))
  (check-equal? (call-with-values
                 (lambda () (op-def-use '(store ($ p) 0 ($ t) (b64))))
                 list)
                '(() (($ p) ($ t))))
  (check-equal? (call-with-values
                 (lambda () (op-def-use '(addr ($ p) ($ x))))
                 list)
                '((($ p)) (($ x))))
  (check-equal? (call-with-values
                 (lambda () (op-def-use '(call ($ r) (global (f)) ($ a) 1)))
                 list)
                '((($ r)) (($ a)))))

(test-case "def-use for asm uses inputs and outputs"
  (define op
    '(asm
      (inputs (($ a) (native x10)) (($ b) (native x11)))
      (outputs (($ r) (native x12)))
      (clobber (native x13))
      (code (add (native x12) (native x10) (native x11)))))
  (check-equal? (call-with-values (lambda () (op-def-use op)) list)
                '((($ r)) (($ a) ($ b)))))

(test-case "def-use for terms"
  (check-equal? (call-with-values
                 (lambda () (term-def-use '(term (branch (eq ($ a) ($ b)) b1 b2))))
                 list)
                '(() (($ a) ($ b))))
  (check-equal? (call-with-values
                 (lambda () (term-def-use '(term (return ($ a) ($ b)))))
                 list)
                '(() (($ a) ($ b))))
  (check-equal? (call-with-values
                 (lambda () (term-def-use '(term (jump b1))))
                 list)
                '(() ())))

;; ---------------------------------------------------------------------------
;; liveness
;; ---------------------------------------------------------------------------

(test-case "minimal live-in / live-out"
  (define lv (analyze-liveness minimal-virtual))
  (check-equal? (block-live lv 'b0) '((($ a) ($ b)) ()))
  (check-equal? (instruction-summary lv 'b0)
                '((add (($ a) ($ b)) (($ t)))
                  (term (($ t)) ()))))

(test-case "branch liveness flows through both successors"
  (define lv (analyze-liveness branch-virtual))
  (check-equal? (block-live lv 'b0) '((($ a) ($ b)) (($ t))))
  (check-equal? (block-live lv 'b1) '((($ t)) (($ t))))
  (check-equal? (block-live lv 'b2) '((($ t)) ()))
  (check-equal? (instruction-summary lv 'b0)
                '((add (($ a) ($ b)) (($ t)))
                  (term (($ t)) (($ t)))))
  (check-equal? (instruction-summary lv 'b1)
                '((add (($ t)) (($ t)))
                  (term (($ t)) (($ t))))))

(test-case "asm inputs are live before and outputs after"
  (define func
    '(func (main)
       (vregs
         (($ a) (b64))
         (($ b) (b64))
         (($ r) (b64)))
       (entry b0)
       (block b0
         (asm
           (inputs (($ a) (native x10)) (($ b) (native x11)))
           (outputs (($ r) (native x12)))
           (clobber (native x13))
           (code (add (native x12) (native x10) (native x11))))
         (term (return ($ r))))))
  (define lv (analyze-liveness func))
  (check-equal? (block-live lv 'b0) '((($ a) ($ b)) ()))
  (check-equal? (instruction-summary lv 'b0)
                '((asm (($ a) ($ b)) (($ r)))
                  (term (($ r)) ()))))
