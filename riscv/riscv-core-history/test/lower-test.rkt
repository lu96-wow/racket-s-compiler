#lang racket
;;; test/lower-test.rkt
;;;
;;; lower-ops：machine IR -> selected machine IR。
;;; 只测指令选择；call/return/asm/global addr 等留给后面。

(require rackunit
         "../core/sexp.rkt"
         "../ir/verify.rkt"
         "../ir/materialize.rkt"
         "../ir/frame.rkt"
         "../ir/lower.rkt"
         "../examples/minimal.rkt"
         "../examples/branch.rkt"
         "../examples/allocation.rkt"
         "../examples/stack-local.rkt")

(define (contains-vreg? x)
  (cond
    [(vreg? x) #t]
    [(list? x) (ormap contains-vreg? x)]
    [else #f]))

(define (contains-frame-slot? x)
  (cond
    [(and (form? x) (eq? (car x) 'frame-slot)) #t]
    [(list? x) (ormap contains-frame-slot? x)]
    [else #f]))

(define (lower-ok func allocation [scratch '()])
  (verify-virtual (list func))
  (define machine (materialize-func func allocation #:scratch scratch))
  (define frame (frame-layout func allocation))
  (define lowered (lower-func machine frame #:scratch scratch))
  (check-false (contains-vreg? lowered))
  (check-false (contains-frame-slot? lowered))
  lowered)

(define (lower-error rx func allocation scratch [xlen 64])
  (define machine (materialize-func func allocation #:scratch scratch))
  (define frame (frame-layout func allocation))
  (check-exn rx
             (lambda ()
               (lower-func machine frame #:xlen xlen #:scratch scratch))))

(define scratch1 (list '(native x5)))
(define scratch2 (list '(native x5) '(native x6)))

(define empty-frame
  '(frame
     (size 16)
     (header 16)
     (outgoing 0)
     (align 16)
     (slots)))

;; ---------------------------------------------------------------------------
;; 基础
;; ---------------------------------------------------------------------------

(test-case "minimal register function"
  (check-equal?
   (lower-ok minimal-virtual register-allocation)
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (entry b0)
      (block b0
        (add (native x12) (native x10) (native x11))
        (term (return (native x12)))))))

(test-case "branch function"
  (check-equal?
   (lower-ok branch-virtual branch-allocation)
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (entry b0)
      (block b0
        (add (native x12) (native x10) (native x11))
        (term (branch (eq (native x12) 0) b2 b1)))
      (block b1
        (addi (native x12) (native x12) 1)
        (term (jump b2)))
      (block b2
        (term (return (native x12)))))))

(test-case "spill load becomes a native load from FP"
  (check-equal?
   (lower-ok minimal-virtual spill-allocation scratch1)
   '(func (main)
      (frame
        (size 32)
        (header 16)
        (outgoing 0)
        (align 16)
        (slots
          (slot 0 (offset 17) (size 1) (align 1))))
      (scratch (native x5))
      (entry b0)
      (block b0
        (lbu (native x5) (native x8) -17)
        (add (native x12) (native x10) (native x5))
        (term (return (native x12)))))))

(test-case "stack-local keeps explicit addr"
  (check-equal?
   (lower-ok stack-local-virtual stack-local-allocation)
   '(func (main)
      (frame
        (size 32)
        (header 16)
        (outgoing 0)
        (align 16)
        (slots
          (slot 0 (offset 24) (size 8) (align 8))))
      (entry b0)
      (block b0
        (addi (native x11) (native x0) 42)
        (addi (native x10) (native x8) -24)
        (sd 0 (native x10) (native x11))
        (ld (native x11) (native x10) 0)
        (term (return (native x11)))))))

;; ---------------------------------------------------------------------------
;; const / copy / binary
;; ---------------------------------------------------------------------------

(test-case "const small and large"
  (define func
    '(func (main)
       (vregs
         (($ t) (b64)))
       (entry b0)
       (block b0
         (const ($ t) 7)
         (const ($ t) 65536)
         (term (return ($ t))))))
  (define allocation
    '(allocation
       (($ t) (native x12))))
  (check-equal?
   (lower-ok func allocation)
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (entry b0)
      (block b0
        (addi (native x12) (native x0) 7)
        (lui (native x12) 16)
        (term (return (native x12)))))))

(test-case "copy becomes addi"
  (define func
    '(func (main)
       (vregs
         (($ a) (b64))
         (($ t) (b64)))
       (entry b0)
       (block b0
         (copy ($ t) ($ a))
         (copy ($ t) 7)
         (term (return ($ t))))))
  (define allocation
    '(allocation
       (($ a) (native x10))
       (($ t) (native x12))))
  (check-equal?
   (lower-ok func allocation)
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (entry b0)
      (block b0
        (addi (native x12) (native x10) 0)
        (addi (native x12) (native x0) 7)
        (term (return (native x12)))))))

(test-case "binary immediate selection"
  (define func
    '(func (main)
       (vregs
         (($ a) (b64))
         (($ t) (b64)))
       (entry b0)
       (block b0
         (add ($ t) ($ a) 1)
         (sub ($ t) ($ a) 1)
         (and ($ t) ($ a) 7)
         (or ($ t) ($ a) 7)
         (xor ($ t) ($ a) 7)
         (shl ($ t) ($ a) 3)
         (shr ($ t) ($ a) 3)
         (sar ($ t) ($ a) 3)
         (term (return ($ t))))))
  (define allocation
    '(allocation
       (($ a) (native x10))
       (($ t) (native x12))))
  (check-equal?
   (lower-ok func allocation)
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (entry b0)
      (block b0
        (addi (native x12) (native x10) 1)
        (addi (native x12) (native x10) -1)
        (andi (native x12) (native x10) 7)
        (ori (native x12) (native x10) 7)
        (xori (native x12) (native x10) 7)
        (slli (native x12) (native x10) 3)
        (srli (native x12) (native x10) 3)
        (srai (native x12) (native x10) 3)
        (term (return (native x12)))))))

(test-case "large immediate uses scratch and li"
  (define func
    '(func (main)
       (vregs
         (($ a) (b64))
         (($ t) (b64)))
       (entry b0)
       (block b0
         (add ($ t) ($ a) 5000)
         (term (return ($ t))))))
  (define allocation
    '(allocation
       (($ a) (native x10))
       (($ t) (native x12))))
  (check-equal?
   (lower-ok func allocation scratch1)
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (scratch (native x5))
      (entry b0)
      (block b0
        (lui (native x5) 1)
        (addi (native x5) (native x5) 904)
        (add (native x12) (native x10) (native x5))
        (term (return (native x12)))))))

;; ---------------------------------------------------------------------------
;; load / store 类型
;; ---------------------------------------------------------------------------

(test-case "load and store type table"
  (define func
    '(func (main)
       (vregs
         (($ p) (ptr))
         (($ t) (b64)))
       (entry b0)
       (block b0
         (load ($ t) ($ p) 0 (b8))
         (load ($ t) ($ p) 0 (s8))
         (load ($ t) ($ p) 0 (b16))
         (load ($ t) ($ p) 0 (s16))
         (load ($ t) ($ p) 0 (b32))
         (load ($ t) ($ p) 0 (s32))
         (load ($ t) ($ p) 0 (b64))
         (load ($ t) ($ p) 0 (ptr))
         (store ($ p) 0 ($ t) (b8))
         (store ($ p) 0 ($ t) (s8))
         (store ($ p) 0 ($ t) (b16))
         (store ($ p) 0 ($ t) (s16))
         (store ($ p) 0 ($ t) (b32))
         (store ($ p) 0 ($ t) (s32))
         (store ($ p) 0 ($ t) (b64))
         (store ($ p) 0 ($ t) (ptr))
         (term (return ($ t))))))
  (define allocation
    '(allocation
       (($ p) (native x10))
       (($ t) (native x11))))
  (check-equal?
   (lower-ok func allocation)
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (entry b0)
      (block b0
        (lbu (native x11) (native x10) 0)
        (lb (native x11) (native x10) 0)
        (lhu (native x11) (native x10) 0)
        (lh (native x11) (native x10) 0)
        (lwu (native x11) (native x10) 0)
        (lw (native x11) (native x10) 0)
        (ld (native x11) (native x10) 0)
        (ld (native x11) (native x10) 0)
        (sb 0 (native x10) (native x11))
        (sb 0 (native x10) (native x11))
        (sh 0 (native x10) (native x11))
        (sh 0 (native x10) (native x11))
        (sw 0 (native x10) (native x11))
        (sw 0 (native x10) (native x11))
        (sd 0 (native x10) (native x11))
        (sd 0 (native x10) (native x11))
        (term (return (native x11)))))))

(test-case "out-of-range load offset uses scratch"
  (define func
    '(func (main)
       (vregs
         (($ p) (ptr))
         (($ t) (b64)))
       (entry b0)
       (block b0
         (load ($ t) ($ p) 5000 (b64))
         (term (return ($ t))))))
  (define allocation
    '(allocation
       (($ p) (native x10))
       (($ t) (native x11))))
  (check-equal?
   (lower-ok func allocation scratch1)
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (scratch (native x5))
      (entry b0)
      (block b0
        (lui (native x5) 1)
        (addi (native x5) (native x5) 904)
        (add (native x5) (native x10) (native x5))
        (ld (native x11) (native x5) 0)
        (term (return (native x11)))))))

(test-case "out-of-range store offset with integer src uses two scratch"
  (define func
    '(func (main)
       (vregs
         (($ p) (ptr)))
       (entry b0)
       (block b0
         (store ($ p) 5000 42 (b64))
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ p) (native x10))))
  (check-equal?
   (lower-ok func allocation scratch2)
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (scratch (native x5) (native x6))
      (entry b0)
      (block b0
        (addi (native x5) (native x0) 42)
        (lui (native x6) 1)
        (addi (native x6) (native x6) 904)
        (add (native x6) (native x10) (native x6))
        (sd 0 (native x6) (native x5))
        (term (return 0))))))

;; ---------------------------------------------------------------------------
;; addr
;; ---------------------------------------------------------------------------

(test-case "addr frame-slot small offset"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken))
         (($ p) (ptr)))
       (entry b0)
       (block b0
         (addr ($ p) ($ x))
         (term (return ($ p))))))
  (define allocation
    '(allocation
       (($ x) (slot 0))
       (($ p) (native x10))))
  (check-equal?
   (lower-ok func allocation)
   '(func (main)
      (frame
        (size 32)
        (header 16)
        (outgoing 0)
        (align 16)
        (slots
          (slot 0 (offset 24) (size 8) (align 8))))
      (entry b0)
      (block b0
        (addi (native x10) (native x8) -24)
        (term (return (native x10)))))))

(test-case "addr frame-slot large offset uses li + add"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken) (align 4096))
         (($ p) (ptr)))
       (entry b0)
       (block b0
         (addr ($ p) ($ x))
         (term (return ($ p))))))
  (define allocation
    '(allocation
       (($ x) (slot 0))
       (($ p) (native x10))))
  (check-equal?
   (lower-ok func allocation)
   '(func (main)
      (frame
        (size 4112)
        (header 16)
        (outgoing 0)
        (align 16)
        (slots
          (slot 0 (offset 4104) (size 8) (align 4096))))
      (entry b0)
      (block b0
        (lui (native x10) 1048575)
        (addi (native x10) (native x10) -8)
        (add (native x10) (native x8) (native x10))
        (term (return (native x10)))))))

(test-case "global addr is left for address lowering"
  (define func
    '(func (main)
       (vregs
         (($ p) (ptr)))
       (entry b0)
       (block b0
         (addr ($ p) (global (d)))
         (term (return ($ p))))))
  (define allocation
    '(allocation
       (($ p) (native x10))))
  (check-equal?
   (lower-ok func allocation)
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (entry b0)
      (block b0
        (addr (native x10) (global (d)))
        (term (return (native x10)))))))

(test-case "call is left for call lowering"
  (define func
    '(func (main)
       (vregs
         (($ t) (b64)))
       (entry b0)
       (block b0
         (call ($ t) (global (f)))
         (term (return ($ t))))))
  (define allocation
    '(allocation
       (($ t) (native x10))))
  (check-equal?
   (lower-ok func allocation)
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (entry b0)
      (block b0
        (call (native x10) (global (f)))
        (term (return (native x10)))))))

;; ---------------------------------------------------------------------------
;; 错误
;; ---------------------------------------------------------------------------

(test-case "b64 load on RV32 is explicit error"
  (define func
    '(func (main)
       (vregs
         (($ p) (ptr))
         (($ t) (b64)))
       (entry b0)
       (block b0
         (load ($ t) ($ p) 0 (b64))
         (term (return ($ t))))))
  (define allocation
    '(allocation
       (($ p) (native x10))
       (($ t) (native x11))))
  (lower-error #rx"b64 load on RV32"
               func allocation '() 32))

(test-case "not enough scratch for out-of-range load"
  (define func
    '(func (main)
       (vregs
         (($ p) (ptr))
         (($ t) (b64)))
       (entry b0)
       (block b0
         (load ($ t) ($ p) 5000 (b64))
         (term (return ($ t))))))
  (define allocation
    '(allocation
       (($ p) (native x10))
       (($ t) (native x11))))
  (lower-error #rx"not enough scratch"
               func allocation '()))
