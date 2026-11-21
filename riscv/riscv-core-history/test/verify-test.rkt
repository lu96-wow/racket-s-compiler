#lang racket
;;; test/verify-test.rkt
;;;
;;; Step 0/1：virtual IR 形状与 verify-virtual。

(require rackunit
         "../ir/verify.rkt"
         "../ir/shape.rkt"
         "../examples/minimal.rkt"
         "../examples/branch.rkt"
         "../examples/asm.rkt"
         "../examples/module.rkt"
         "../examples/stack-local.rkt")

(define (check-verify-ok program)
  (check-equal? (verify-virtual program) program))

(define (check-verify-error rx program)
  (check-exn rx (lambda () (verify-virtual program))))

;; ---------------------------------------------------------------------------
;; 形状单独测
;; ---------------------------------------------------------------------------

(test-case "type forms"
  (for ([t '((b8) (b16) (b32) (b64) (s8) (s16) (s32) (ptr))])
    (check-true (type-form? t)))
  (for ([t '((u8) (b128) (int) (b64 8) b64)])
    (check-false (type-form? t))))

(test-case "vreg declarations"
  (check-true (vreg-decl? '(($ a) (b8))))
  (check-true (vreg-decl? '(($ a) (b64) (align 8))))
  (check-true (vreg-decl? '(($ a) (b64) (address-taken))))
  (check-false (vreg-decl? '(($ a))))
  (check-false (vreg-decl? '((a) (b8))))
  (check-false (vreg-decl? '(($ a) (b8) (align 0))))
  (check-false (vreg-decl? '(($ a) (b8) (unknown)))))

(test-case "physical registers"
  (check-true (physical-register? '(native x0)))
  (check-true (physical-register? '(native x31)))
  (check-false (physical-register? '(native x32)))
  (check-false (physical-register? '(native a0)))
  (check-false (physical-register? '(native ra))))

;; ---------------------------------------------------------------------------
;; 合法程序
;; ---------------------------------------------------------------------------

(test-case "examples/minimal.rkt passes"
  (check-verify-ok (list minimal-virtual)))

(test-case "examples/branch.rkt passes"
  (check-verify-ok (list branch-virtual)))

(test-case "examples/asm.rkt passes"
  (check-verify-ok (list asm-add)))

(test-case "stack-local example passes"
  (check-verify-ok (list stack-local-virtual)))

(test-case "resolved module example passes"
  (check-verify-ok module-resolved))

(define kitchen-sink
  '(func (all)
     (vregs
       (($ a) (b8))
       (($ b) (b8))
       (($ t) (b64))
       (($ p) (ptr))
       (($ x) (b64) (address-taken) (align 8)))
     (alloc
       (reserve (native x5))
       (pin ($ t) (native x11))
       (clobber (native x5) (native x6)))
     (entry b0)
     (block b0
       (const ($ t) 42)
       (copy ($ t) ($ a))
       (add ($ t) ($ a) ($ b))
       (sub ($ t) ($ t) 1)
       (and ($ t) ($ a) ($ b))
       (or ($ t) ($ a) ($ b))
       (xor ($ t) ($ a) ($ b))
       (shl ($ t) ($ a) 1)
       (shr ($ t) ($ a) 1)
       (sar ($ t) ($ a) 1)
       (mul ($ t) ($ a) ($ b))
       (div ($ t) ($ a) ($ b))
       (divu ($ t) ($ a) ($ b))
       (rem ($ t) ($ a) ($ b))
       (remu ($ t) ($ a) ($ b))
       (load ($ t) ($ p) 0 (b64))
       (store ($ p) 8 ($ t) (b64))
       (addr ($ p) (global (data)))
       (addr ($ p) ($ x))
       (call ($ t) (global (f)) ($ a) ($ b))
       (term (branch (eq ($ t) 0) b1 b2)))
     (block b1
       (term (jump b2)))
     (block b2
       (term (return ($ t))))))

(test-case "all ordinary ops pass verification"
  (check-verify-ok (list kitchen-sink)))

(test-case "empty vregs is allowed, missing vregs is not"
  (check-verify-ok
   '((func (main)
       (vregs)
       (entry b0)
       (block b0
         (term (return 0))))))
  (check-verify-error
   #rx"missing \\(vregs"
   '((func (main)
       (entry b0)
       (block b0
         (term (return 0)))))))

;; ---------------------------------------------------------------------------
;; 顶层
;; ---------------------------------------------------------------------------

(test-case "virtual program rejects data and raw"
  (check-verify-error
   #rx"top level only accepts func"
   '((data (d) (bytes 1 2))))
  (check-verify-error
   #rx"top level only accepts func"
   '((raw (start)
       (j (start))))))

;; ---------------------------------------------------------------------------
;; vregs / alloc
;; ---------------------------------------------------------------------------

(test-case "duplicate vreg declaration"
  (check-verify-error
   #rx"declared twice"
   '((func (main)
       (vregs
         (($ a) (b64))
         (($ a) (b64)))
       (entry b0)
       (block b0
         (term (return 0)))))))

(test-case "malformed vreg declaration"
  (check-verify-error
   #rx"malformed vreg declaration"
   '((func (main)
       (vregs
         (($ a) (u64)))
       (entry b0)
       (block b0
         (term (return 0)))))))

(test-case "duplicate vreg option"
  (check-verify-error
   #rx"duplicate option"
   '((func (main)
       (vregs
         (($ a) (b64) (address-taken) (address-taken)))
       (entry b0)
       (block b0
         (term (return 0)))))))

(test-case "pin must refer to a declared vreg"
  (check-verify-error
   #rx"undeclared vreg"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (alloc
         (pin ($ missing) (native x10)))
       (entry b0)
       (block b0
         (term (return 0)))))))

(test-case "address-taken vreg cannot be pinned"
  (check-verify-error
   #rx"address-taken vreg .* cannot be pinned"
   '((func (main)
       (vregs
         (($ a) (b64) (address-taken)))
       (alloc
         (pin ($ a) (native x10)))
       (entry b0)
       (block b0
         (term (return 0)))))))

(test-case "a vreg cannot be pinned to two registers"
  (check-verify-error
   #rx"pinned to two registers"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (alloc
         (pin ($ a) (native x10))
         (pin ($ a) (native x11)))
       (entry b0)
       (block b0
         (term (return 0)))))))

(test-case "alloc rejects ABI register aliases"
  (check-verify-error
   #rx"invalid alloc entry"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (alloc
         (pin ($ a) (native a0)))
       (entry b0)
       (block b0
         (term (return 0)))))))

;; ---------------------------------------------------------------------------
;; entry / blocks / terms
;; ---------------------------------------------------------------------------

(test-case "missing entry"
  (check-verify-error
   #rx"missing \\(entry"
   '((func (main)
       (vregs)
       (block b0
         (term (return 0)))))))

(test-case "duplicate entry"
  (check-verify-error
   #rx"more than one entry"
   '((func (main)
       (vregs)
       (entry b0)
       (entry b1)
       (block b0 (term (return 0)))
       (block b1 (term (return 0)))))))

(test-case "entry block must exist"
  (check-verify-error
   #rx"entry block .* is not declared"
   '((func (main)
       (vregs)
       (entry b9)
       (block b0 (term (return 0)))))))

(test-case "duplicate block"
  (check-verify-error
   #rx"declared twice"
   '((func (main)
       (vregs)
       (entry b0)
       (block b0 (term (return 0)))
       (block b0 (term (return 0)))))))

(test-case "block without term"
  (check-verify-error
   #rx"has no term"
   '((func (main)
       (vregs)
       (entry b0)
       (block b0
         (const ($ a) 1))))))

(test-case "term must be last"
  (check-verify-error
   #rx"term must be the last"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (entry b0)
       (block b0
         (term (return 0))
         (const ($ a) 1))))))

(test-case "multiple terms"
  (check-verify-error
   #rx"more than one term"
   '((func (main)
       (vregs)
       (entry b0)
       (block b0
         (term (return 0))
         (term (trap)))))))

(test-case "jump target must exist"
  (check-verify-error
   #rx"undeclared block"
   '((func (main)
       (vregs)
       (entry b0)
       (block b0
         (term (jump missing)))))))

(test-case "condition must not use a global directly"
  (check-verify-error
   #rx"condition operand must be integer or vreg"
   '((func (main)
       (vregs)
       (entry b0)
       (block b0
         (term (branch (eq (global (f)) 0) b0 b0)))))))

(test-case "condition vreg must be declared"
  (check-verify-error
   #rx"condition uses undeclared vreg"
   '((func (main)
       (vregs)
       (entry b0)
       (block b0
         (term (branch (eq ($ missing) 0) b0 b0)))))))

;; ---------------------------------------------------------------------------
;; 普通 op
;; ---------------------------------------------------------------------------

(test-case "op vreg must be declared"
  (check-verify-error
   #rx"undeclared vreg"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (entry b0)
       (block b0
         (add ($ missing) ($ a) 1)
         (term (return 0)))))))

(test-case "unknown op"
  (check-verify-error
   #rx"unknown virtual op"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (entry b0)
       (block b0
         (nop)
         (term (return 0)))))))

(test-case "control and machine forms are forbidden in blocks"
  (for ([op '((j (b0))
              (label b0)
              (slot 0)
              (frame (size 8)))])
    (check-verify-error
     #rx"not allowed in virtual IR|unknown virtual op"
     (list (list 'func '(main)
                 '(vregs (($ a) (b64)))
                 '(entry b0)
                 (list* 'block 'b0 (list op) (list '(term (return 0)))))))))

(test-case "native is not an ordinary op"
  (check-verify-error
   #rx"unknown virtual op"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (entry b0)
       (block b0
         (native x10)
         (term (return 0)))))))

(test-case "const shape"
  (check-verify-error
   #rx"expects 2 operands"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (entry b0)
       (block b0
         (const ($ a))
         (term (return 0))))))
  (check-verify-error
   #rx"const immediate must be an integer"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (entry b0)
       (block b0
         (const ($ a) x)
         (term (return 0)))))))

(test-case "load type and offset"
  (check-verify-error
   #rx"invalid type"
   '((func (main)
       (vregs
         (($ a) (b64))
         (($ p) (ptr)))
       (entry b0)
       (block b0
         (load ($ a) ($ p) 0 (u64))
         (term (return 0))))))
  (check-verify-error
   #rx"load offset must be an integer"
   '((func (main)
       (vregs
         (($ a) (b64))
         (($ p) (ptr)))
       (entry b0)
       (block b0
         (load ($ a) ($ p) x (b64))
         (term (return 0)))))))

(test-case "addr source must be global or address-taken vreg"
  (check-verify-error
   #rx"is not \\(address-taken\\)"
   '((func (main)
       (vregs
         (($ a) (b64))
         (($ p) (ptr)))
       (entry b0)
       (block b0
         (addr ($ p) ($ a))
         (term (return 0))))))
  (check-verify-error
   #rx"addr source must be"
   '((func (main)
       (vregs
         (($ p) (ptr)))
       (entry b0)
       (block b0
         (addr ($ p) 42)
         (term (return 0)))))))

(test-case "call target must be a global"
  (check-verify-error
   #rx"call target must be \\(global chain\\)"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (entry b0)
       (block b0
         (call ($ a) ($ a))
         (term (return 0)))))))

;; ---------------------------------------------------------------------------
;; asm
;; ---------------------------------------------------------------------------

(test-case "asm missing clause"
  (check-verify-error
   #rx"asm is missing code"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (entry b0)
       (block b0
         (asm
           (inputs)
           (outputs)
           (clobber))
         (term (return 0)))))))

(test-case "asm duplicate clause"
  (check-verify-error
   #rx"duplicate inputs clause"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (entry b0)
       (block b0
         (asm
           (inputs (($ a) (native x10)))
           (inputs)
           (outputs)
           (clobber)
           (code))
         (term (return 0)))))))

(test-case "asm input vreg must be declared"
  (check-verify-error
   #rx"asm inputs uses undeclared vreg"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (entry b0)
       (block b0
         (asm
           (inputs (($ missing) (native x10)))
           (outputs)
           (clobber)
           (code))
         (term (return 0)))))))

(test-case "asm code may not contain vreg or global"
  (check-verify-error
   #rx"asm.code may not contain \\$"
   '((func (main)
       (vregs
         (($ a) (b64)))
       (entry b0)
       (block b0
         (asm
           (inputs)
           (outputs)
           (clobber)
           (code
             (add (native x10) ($ a) (native x11))))
         (term (return 0))))))
  (check-verify-error
   #rx"asm.code may not contain global"
   '((func (main)
       (vregs)
       (entry b0)
       (block b0
         (asm
           (inputs)
           (outputs)
           (clobber)
           (code
             (j (global (f)))))
         (term (return 0)))))))

(test-case "asm code rejects ABI register aliases"
  (check-verify-error
   #rx"asm.code native register must be x0..x31"
   '((func (main)
       (vregs)
       (entry b0)
       (block b0
         (asm
           (inputs)
           (outputs)
           (clobber)
           (code
             (add (native a0) (native x10) (native x11))))
         (term (return 0)))))))

(test-case "asm label must have symbols"
  (check-verify-error
   #rx"asm.code label must take one or more symbols"
   '((func (main)
       (vregs)
       (entry b0)
       (block b0
         (asm
           (inputs)
           (outputs)
           (clobber)
           (code
             (label)))
         (term (return 0)))))))
