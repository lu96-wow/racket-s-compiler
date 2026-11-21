#lang racket
;;; test/verify-machine-test.rkt
;;;
;;; machine IR：没有 ($ x)、没有裸 (slot n)、frame/scratch/term 形状合法。

(require rackunit
         "../core/sexp.rkt"
         "../ir/verify.rkt"
         "../ir/verify-machine.rkt"
         "../ir/materialize.rkt"
         "../ir/frame.rkt"
         "../ir/lower.rkt"
         "../ir/call-lower.rkt"
         "../examples/minimal.rkt"
         "../examples/branch.rkt"
         "../examples/allocation.rkt"
         "../examples/stack-local.rkt")

(define (check-machine-ok func)
  (check-equal? (verify-machine (list func)) (list func)))

(define (check-machine-error rx func)
  (check-exn rx (lambda () (verify-machine (list func)))))

(define frame16
  '(frame
     (size 16)
     (header 16)
     (outgoing 0)
     (align 16)
     (slots)))

(define frame32-out8
  '(frame
     (size 32)
     (header 16)
     (outgoing 8)
     (align 16)
     (slots)))

;; ---------------------------------------------------------------------------
;; 真实流水线输出
;; ---------------------------------------------------------------------------

(test-case "materialized register-only minimal is machine IR"
  (check-machine-ok
   (materialize-func minimal-virtual register-allocation)))

(test-case "materialized spill function is machine IR"
  (check-machine-ok
   (materialize-func minimal-virtual spill-allocation #:scratch (list '(native x5)))))

(test-case "materialized branch function is machine IR"
  (check-machine-ok
   (materialize-func branch-virtual branch-allocation)))

(test-case "materialized stack-local function is machine IR"
  (check-machine-ok
   (materialize-func stack-local-virtual stack-local-allocation)))

(test-case "lowered minimal function is machine IR"
  (define machine (materialize-func minimal-virtual register-allocation))
  (define frame (frame-layout minimal-virtual register-allocation))
  (check-machine-ok (lower-func machine frame)))

(test-case "lowered spill function is machine IR"
  (define scratch (list '(native x5)))
  (define machine (materialize-func minimal-virtual spill-allocation #:scratch scratch))
  (define frame (frame-layout minimal-virtual spill-allocation))
  (check-machine-ok (lower-func machine frame #:scratch scratch)))

(test-case "lowered stack-local function is machine IR"
  (define machine (materialize-func stack-local-virtual stack-local-allocation))
  (define frame (frame-layout stack-local-virtual stack-local-allocation))
  (check-machine-ok (lower-func machine frame)))

(test-case "call-lowered function with call-target is machine IR"
  (define func
    '(func (main)
       (frame (size 32) (header 16) (outgoing 8) (align 16) (slots))
       (scratch (native x5) (native x6))
       (entry b0)
       (block b0
         (call (native x10) (global (f)) (native x11))
         (term (return (native x10))))))
  (check-machine-ok (lower-calls func frame32-out8)))

;; ---------------------------------------------------------------------------
;; 合法形状
;; ---------------------------------------------------------------------------

(test-case "return may still carry a machine operand before call-lower"
  (check-machine-ok
   '(func (main)
      (entry b0)
      (block b0
        (add (native x12) (native x10) (native x11))
        (term (return (native x12)))))))

(test-case "frame-slot is a legal machine address"
  (check-machine-ok
   '(func (main)
      (frame
        (size 32)
        (header 16)
        (outgoing 0)
        (align 16)
        (slots
          (slot 0 (offset 24) (size 8) (align 8))))
      (scratch (native x5))
      (entry b0)
      (block b0
        (load (native x5) (frame-slot 0) 0 (b64))
        (term (return (native x5)))))))

(test-case "empty scratch and empty slots are legal"
  (check-machine-ok
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (scratch)
      (entry b0)
      (block b0 (term (trap))))))

;; ---------------------------------------------------------------------------
;; 虚拟 / layout 形状泄漏
;; ---------------------------------------------------------------------------

(test-case "vreg is rejected"
  (check-machine-error
   #rx"still contains vreg"
   '(func (main)
      (entry b0)
      (block b0
        (add (native x12) ($ a) (native x11))
        (term (return (native x12)))))))

(test-case "bare slot is rejected"
  (check-machine-error
   #rx"bare \\(slot n\\)"
   '(func (main)
      (scratch (native x5))
      (entry b0)
      (block b0
        (load (native x5) (slot 0) 0 (b64))
        (term (return (native x5)))))))

(test-case "vregs form is rejected"
  (check-machine-error
   #rx"virtual allocation form"
   '(func (main)
      (vregs (($ a) (b64)))
      (entry b0)
      (block b0 (term (trap))))))

(test-case "alloc form is rejected"
  (check-machine-error
   #rx"virtual allocation form"
   '(func (main)
      (alloc (reserve (native x5)))
      (entry b0)
      (block b0 (term (trap))))))

(test-case "label in a machine op is rejected"
  (check-machine-error
   #rx"not a machine op before layout"
   '(func (main)
      (entry b0)
      (block b0
        (label b1)
        (term (trap))))))

(test-case "j in a machine op is rejected"
  (check-machine-error
   #rx"not a machine op before layout"
   '(func (main)
      (entry b0)
      (block b0
        (j b1)
        (term (trap))))))

(test-case "conditional branch before layout is rejected"
  (check-machine-error
   #rx"not a machine op before layout"
   '(func (main)
      (entry b0)
      (block b0
        (beq b1 (native x10) (native x11))
        (term (trap))))))

;; ---------------------------------------------------------------------------
;; 非法操作数
;; ---------------------------------------------------------------------------

(test-case "ABI register name is rejected"
  (check-machine-error
   #rx"malformed native register"
   '(func (main)
      (entry b0)
      (block b0
        (addi (native a0) (native x10) 0)
        (term (trap))))))

(test-case "malformed frame-slot is rejected"
  (check-machine-error
   #rx"malformed frame-slot"
   '(func (main)
      (scratch (native x5))
      (entry b0)
      (block b0
        (load (native x5) (frame-slot nope) 0 (b64))
        (term (trap))))))

(test-case "frame-slot must exist in the frame"
  (check-machine-error
   #rx"frame-slot 1 has no entry"
   '(func (main)
      (frame
        (size 32)
        (header 16)
        (outgoing 0)
        (align 16)
        (slots
          (slot 0 (offset 24) (size 8) (align 8))))
      (scratch (native x5))
      (entry b0)
      (block b0
        (load (native x5) (frame-slot 1) 0 (b64))
        (term (trap))))))

(test-case "bare symbol operand is rejected"
  (check-machine-error
   #rx"bare symbol"
   '(func (main)
      (entry b0)
      (block b0
        (addi (native x10) (native x11) foo)
        (term (trap))))))

;; ---------------------------------------------------------------------------
;; block / term
;; ---------------------------------------------------------------------------

(test-case "missing term is rejected"
  (check-machine-error
   #rx"has no term"
   '(func (main)
      (entry b0)
      (block b0
        (addi (native x10) (native x11) 0)))))

(test-case "term must be last"
  (check-machine-error
   #rx"term must be the last form"
   '(func (main)
      (entry b0)
      (block b0
        (term (trap))
        (addi (native x10) (native x11) 0)))))

(test-case "two terms are rejected"
  (check-machine-error
   #rx"more than one term"
   '(func (main)
      (entry b0)
      (block b0
        (term (trap))
        (term (trap))))))

(test-case "missing entry is rejected"
  (check-machine-error
   #rx"missing \\(entry"
   '(func (main)
      (block b0 (term (trap))))))

(test-case "entry must be declared"
  (check-machine-error
   #rx"entry block b9 is not declared"
   '(func (main)
      (entry b9)
      (block b0 (term (trap))))))

(test-case "jump target must be declared"
  (check-machine-error
   #rx"jumps to undeclared block"
   '(func (main)
      (entry b0)
      (block b0 (term (jump b9))))))

(test-case "duplicate block is rejected"
  (check-machine-error
   #rx"declared twice"
   '(func (main)
      (entry b0)
      (block b0 (term (trap)))
      (block b0 (term (trap))))))

;; ---------------------------------------------------------------------------
;; frame / scratch
;; ---------------------------------------------------------------------------

(test-case "malformed frame is rejected"
  (check-machine-error
   #rx"malformed frame"
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16))
      (entry b0)
      (block b0 (term (trap))))))

(test-case "duplicate scratch is rejected"
  (check-machine-error
   #rx"listed twice"
   '(func (main)
      (scratch (native x5) (native x5))
      (entry b0)
      (block b0 (term (trap))))))

(test-case "malformed scratch is rejected"
  (check-machine-error
   #rx"malformed scratch"
   '(func (main)
      (scratch (native a0))
      (entry b0)
      (block b0 (term (trap))))))
