#lang racket
;;; test/materialize-test.rkt
;;;
;;; virtual IR + allocation -> machine IR。
;;; 第一版 stack-first：寄存器直接替换，slot 用 load/store + scratch。

(require rackunit
         "../core/sexp.rkt"
         "../ir/verify.rkt"
         "../ir/materialize.rkt"
         "../examples/minimal.rkt"
         "../examples/branch.rkt"
         "../examples/allocation.rkt"
         "../examples/asm.rkt"
         "../examples/stack-local.rkt")

(define (contains-vreg? x)
  (cond
    [(vreg? x) #t]
    [(list? x) (ormap contains-vreg? x)]
    [else #f]))

(define (materialize-ok func allocation [scratch '()])
  (verify-virtual (list func))
  (define machine (materialize-func func allocation #:scratch scratch))
  (check-false (contains-vreg? machine))
  machine)

(define (check-materialize-error rx func allocation [scratch '()])
  (check-exn rx
             (lambda ()
               (materialize-func func allocation #:scratch scratch))))

(define scratch1 (list '(native x5)))
(define scratch2 (list '(native x5) '(native x6)))

;; ---------------------------------------------------------------------------
;; 与已有 machine 例子对齐
;; ---------------------------------------------------------------------------

(test-case "register-only minimal matches the documented machine IR"
  (check-equal? (materialize-ok minimal-virtual register-allocation)
                minimal-machine))

(test-case "register-only branch matches the documented machine IR"
  (check-equal? (materialize-ok branch-virtual branch-allocation)
                branch-machine))

(test-case "spill load uses scratch"
  (check-equal?
   (materialize-ok minimal-virtual spill-allocation scratch1)
   '(func (main)
      (scratch (native x5))
      (entry b0)
      (block b0
        (load (native x5) (frame-slot 0) 0 (b8))
        (add (native x12) (native x10) (native x5))
        (term (return (native x12)))))))

(test-case "stack-local keeps addr explicit"
  (check-equal?
   (materialize-ok stack-local-virtual stack-local-allocation)
   '(func (main)
      (entry b0)
      (block b0
        (const (native x11) 42)
        (addr (native x10) (frame-slot 0))
        (store (native x10) 0 (native x11) (b64))
        (load (native x11) (native x10) 0 (b64))
        (term (return (native x11)))))))

;; ---------------------------------------------------------------------------
;; const / copy
;; ---------------------------------------------------------------------------

(test-case "const to slot uses scratch then store"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken)))
       (entry b0)
       (block b0
         (const ($ x) 7)
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ x) (slot 0))))
  (check-equal?
   (materialize-ok func allocation scratch1)
   '(func (main)
      (scratch (native x5))
      (entry b0)
      (block b0
        (const (native x5) 7)
        (store (frame-slot 0) 0 (native x5) (b64))
        (term (return 0))))))

(test-case "copy slot -> register is a direct load"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken))
         (($ y) (b64)))
       (entry b0)
       (block b0
         (copy ($ y) ($ x))
         (term (return ($ y))))))
  (define allocation
    '(allocation
       (($ x) (slot 0))
       (($ y) (native x10))))
  (check-equal?
   (materialize-ok func allocation)
   '(func (main)
      (entry b0)
      (block b0
        (load (native x10) (frame-slot 0) 0 (b64))
        (term (return (native x10)))))))

(test-case "copy register -> slot is a direct store"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken))
         (($ y) (b64)))
       (entry b0)
       (block b0
         (copy ($ x) ($ y))
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ x) (slot 0))
       (($ y) (native x10))))
  (check-equal?
   (materialize-ok func allocation)
   '(func (main)
      (entry b0)
      (block b0
        (store (frame-slot 0) 0 (native x10) (b64))
        (term (return 0))))))

(test-case "copy slot -> slot uses one scratch"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken))
         (($ y) (b64) (address-taken)))
       (entry b0)
       (block b0
         (copy ($ y) ($ x))
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ x) (slot 0))
       (($ y) (slot 1))))
  (check-equal?
   (materialize-ok func allocation scratch1)
   '(func (main)
      (scratch (native x5))
      (entry b0)
      (block b0
        (load (native x5) (frame-slot 0) 0 (b64))
        (store (frame-slot 1) 0 (native x5) (b64))
        (term (return 0))))))

;; ---------------------------------------------------------------------------
;; 二元 / load / store / addr
;; ---------------------------------------------------------------------------

(test-case "binary with two slot operands and slot dst uses two scratch"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken))
         (($ y) (b64) (address-taken))
         (($ z) (b64) (address-taken)))
       (entry b0)
       (block b0
         (add ($ z) ($ x) ($ y))
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ x) (slot 0))
       (($ y) (slot 1))
       (($ z) (slot 2))))
  (check-equal?
   (materialize-ok func allocation scratch2)
   '(func (main)
      (scratch (native x5) (native x6))
      (entry b0)
      (block b0
        (load (native x5) (frame-slot 0) 0 (b64))
        (load (native x6) (frame-slot 1) 0 (b64))
        (add (native x5) (native x5) (native x6))
        (store (frame-slot 2) 0 (native x5) (b64))
        (term (return 0))))))

(test-case "load with slot base and slot dst uses two scratch"
  (define func
    '(func (main)
       (vregs
         (($ p) (ptr) (address-taken))
         (($ x) (b64) (address-taken)))
       (entry b0)
       (block b0
         (load ($ x) ($ p) 0 (b64))
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ p) (slot 0))
       (($ x) (slot 1))))
  (check-equal?
   (materialize-ok func allocation scratch2)
   '(func (main)
      (scratch (native x5) (native x6))
      (entry b0)
      (block b0
        (load (native x5) (frame-slot 0) 0 (ptr))
        (load (native x6) (native x5) 0 (b64))
        (store (frame-slot 1) 0 (native x6) (b64))
        (term (return 0))))))

(test-case "store with slot base and slot src uses two scratch"
  (define func
    '(func (main)
       (vregs
         (($ p) (ptr) (address-taken))
         (($ x) (b64) (address-taken)))
       (entry b0)
       (block b0
         (store ($ p) 0 ($ x) (b64))
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ p) (slot 0))
       (($ x) (slot 1))))
  (check-equal?
   (materialize-ok func allocation scratch2)
   '(func (main)
      (scratch (native x5) (native x6))
      (entry b0)
      (block b0
        (load (native x5) (frame-slot 0) 0 (ptr))
        (load (native x6) (frame-slot 1) 0 (b64))
        (store (native x5) 0 (native x6) (b64))
        (term (return 0))))))

(test-case "addr to slot uses scratch and stores a pointer"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken))
         (($ p) (ptr) (address-taken)))
       (entry b0)
       (block b0
         (addr ($ p) ($ x))
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ x) (slot 0))
       (($ p) (slot 1))))
  (check-equal?
   (materialize-ok func allocation scratch1)
   '(func (main)
      (scratch (native x5))
      (entry b0)
      (block b0
        (addr (native x5) (frame-slot 0))
        (store (frame-slot 1) 0 (native x5) (ptr))
        (term (return 0))))))

(test-case "branch condition slot is loaded before the term"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken)))
       (entry b0)
       (block b0
         (term (branch (eq ($ x) 0) b1 b2)))
       (block b1
         (term (return 0)))
       (block b2
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ x) (slot 0))))
  (check-equal?
   (materialize-ok func allocation scratch1)
   '(func (main)
      (scratch (native x5))
      (entry b0)
      (block b0
        (load (native x5) (frame-slot 0) 0 (b64))
        (term (branch (eq (native x5) 0) b1 b2)))
      (block b1
        (term (return 0)))
      (block b2
        (term (return 0))))))

;; ---------------------------------------------------------------------------
;; 暂不支持的位置
;; ---------------------------------------------------------------------------

(test-case "not enough scratch"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken)))
       (entry b0)
       (block b0
         (const ($ x) 7)
         (term (return 0)))))
  (check-materialize-error
   #rx"not enough scratch"
   func
   '(allocation
      (($ x) (slot 0)))))

(test-case "call with slot argument loads it into scratch"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken))
         (($ r) (b64)))
       (entry b0)
       (block b0
         (call ($ r) (global (f)) ($ x))
         (term (return ($ r))))))
  (check-equal?
   (materialize-ok func
                   '(allocation
                      (($ x) (slot 0))
                      (($ r) (native x10)))
                   scratch1)
   '(func (main)
      (scratch (native x5))
      (entry b0)
      (block b0
        (load (native x5) (frame-slot 0) 0 (b64))
        (call (native x10) (global (f)) (native x5))
        (term (return (native x10)))))))

(test-case "call with slot destination stores the result after the call"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64))
         (($ r) (b64) (address-taken)))
       (entry b0)
       (block b0
         (call ($ r) (global (f)) ($ x))
         (term (return 0)))))
  (check-equal?
   (materialize-ok func
                   '(allocation
                      (($ x) (native x11))
                      (($ r) (slot 0)))
                   scratch1)
   '(func (main)
      (scratch (native x5))
      (entry b0)
      (block b0
        (call (native x5) (global (f)) (native x11))
        (store (frame-slot 0) 0 (native x5) (b64))
        (term (return 0))))))

(test-case "slot call destination reuses an argument scratch"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken))
         (($ r) (b64) (address-taken)))
       (entry b0)
       (block b0
         (call ($ r) (global (f)) ($ x))
         (term (return 0)))))
  (check-equal?
   (materialize-ok func
                   '(allocation
                      (($ x) (slot 0))
                      (($ r) (slot 1)))
                   scratch1)
   '(func (main)
      (scratch (native x5))
      (entry b0)
      (block b0
        (load (native x5) (frame-slot 0) 0 (b64))
        (call (native x5) (global (f)) (native x5))
        (store (frame-slot 1) 0 (native x5) (b64))
        (term (return 0))))))

(test-case "slot call destination with no scratch is an error"
  (define func
    '(func (main)
       (vregs
         (($ r) (b64) (address-taken)))
       (entry b0)
       (block b0
         (call ($ r) (global (f)))
         (term (return 0)))))
  (check-materialize-error
   #rx"not enough scratch"
   func
   '(allocation
      (($ r) (slot 0)))))

(test-case "return with slot operand loads it before the term"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken)))
       (entry b0)
       (block b0
         (term (return ($ x))))))
  (check-equal?
   (materialize-ok func
                   '(allocation
                      (($ x) (slot 0)))
                   scratch1)
   '(func (main)
      (scratch (native x5))
      (entry b0)
      (block b0
        (load (native x5) (frame-slot 0) 0 (b64))
        (term (return (native x5)))))))

(test-case "inline asm with no moves becomes asm-code"
  (check-equal?
   (materialize-ok asm-add
                   '(allocation
                      (($ a) (native x10))
                      (($ b) (native x11))
                      (($ r) (native x12))))
   '(func (main)
      (entry b0)
      (block b0
        (asm-code
          (label loop)
          (add (native x12) (native x10) (native x11))
          (bne loop (native x10) (native x11)))
        (term (return (native x12)))))))

(test-case "inline asm moves inputs and outputs when locations differ"
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
           (clobber)
           (code (add (native x12) (native x10) (native x11))))
         (term (return ($ r))))))
  (check-equal?
   (materialize-ok func
                   '(allocation
                      (($ a) (native x13))
                      (($ b) (native x14))
                      (($ r) (native x15))))
   '(func (main)
      (entry b0)
      (block b0
        (copy (native x10) (native x13))
        (copy (native x11) (native x14))
        (asm-code (add (native x12) (native x10) (native x11)))
        (copy (native x15) (native x12))
        (term (return (native x15)))))))

(test-case "inline asm loads slot inputs and stores slot outputs"
  (define func
    '(func (main)
       (vregs
         (($ a) (b64) (address-taken))
         (($ r) (b64) (address-taken)))
       (entry b0)
       (block b0
         (asm
           (inputs (($ a) (native x10)))
           (outputs (($ r) (native x12)))
           (clobber)
           (code (add (native x12) (native x10) (native x0))))
         (term (return 0)))))
  (check-equal?
   (materialize-ok func
                   '(allocation
                      (($ a) (slot 0))
                      (($ r) (slot 1))))
   '(func (main)
      (entry b0)
      (block b0
        (load (native x10) (frame-slot 0) 0 (b64))
        (asm-code (add (native x12) (native x10) (native x0)))
        (store (frame-slot 1) 0 (native x12) (b64))
        (term (return 0))))))

(test-case "inline asm parallel move cycle uses scratch"
  (define func
    '(func (main)
       (vregs
         (($ a) (b64))
         (($ b) (b64)))
       (entry b0)
       (block b0
         (asm
           (inputs (($ a) (native x11)) (($ b) (native x10)))
           (outputs)
           (clobber)
           (code (add (native x10) (native x10) (native x11))))
         (term (return 0)))))
  (check-equal?
   (materialize-ok func
                   '(allocation
                      (($ a) (native x10))
                      (($ b) (native x11)))
                   scratch1)
   '(func (main)
      (scratch (native x5))
      (entry b0)
      (block b0
        (copy (native x5) (native x10))
        (copy (native x10) (native x11))
        (copy (native x11) (native x5))
        (asm-code (add (native x10) (native x10) (native x11)))
        (term (return 0))))))

(test-case "inline asm clobber cannot overlap input/output"
  (define func
    '(func (main)
       (vregs (($ a) (b64)))
       (entry b0)
       (block b0
         (asm
           (inputs (($ a) (native x10)))
           (outputs)
           (clobber (native x10))
           (code (add (native x10) (native x10) (native x0))))
         (term (return 0)))))
  (check-materialize-error
   #rx"clobber .* overlaps"
   func
   '(allocation (($ a) (native x10)))))

(test-case "inline asm duplicate input target is rejected"
  (define func
    '(func (main)
       (vregs (($ a) (b64)) (($ b) (b64)))
       (entry b0)
       (block b0
         (asm
           (inputs (($ a) (native x10)) (($ b) (native x10)))
           (outputs)
           (clobber)
           (code (add (native x10) (native x10) (native x10))))
         (term (return 0)))))
  (check-materialize-error
   #rx"input register .* bound to two vregs"
   func
   '(allocation (($ a) (native x11)) (($ b) (native x12)))))
