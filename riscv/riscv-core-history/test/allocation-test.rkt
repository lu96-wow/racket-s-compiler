#lang racket
;;; test/allocation-test.rkt
;;;
;;; Step 3：allocation 表形状与约束。

(require rackunit
         "../ir/allocation.rkt"
         "../examples/minimal.rkt"
         "../examples/allocation.rkt"
         "../examples/stack-local.rkt")

(define (check-allocation-ok func allocation [scratch #f])
  (check-equal? (verify-allocation func allocation scratch) allocation))

(define (check-allocation-error rx func allocation [scratch #f])
  (check-exn rx (lambda () (verify-allocation func allocation scratch))))

;; ---------------------------------------------------------------------------
;; 形状与查表
;; ---------------------------------------------------------------------------

(test-case "allocation shape predicates"
  (check-true (allocation-form? register-allocation))
  (check-true (allocation-form? spill-allocation))
  (check-true (allocation-form? '(allocation)))
  (check-true (allocation-entry? '(($ a) (native x10))))
  (check-true (allocation-entry? '(($ a) (slot 0))))
  (check-false (allocation-entry? '(($ a) (slot -1))))
  (check-false (allocation-entry? '(($ a) (reg x10))))
  (check-false (allocation-entry? '(($ a) . (native x10))))
  (check-false (allocation-form? '(allocation (($ a) (native a0)))))
  (check-true (scratch-form? spill-scratch))
  (check-true (scratch-form? '(scratch (native x5) (native x6))))
  (check-true (scratch-form? '(scratch)))
  (check-false (scratch-form? '(scratch (slot 0))))
  (check-false (scratch-form? '(scratch (native a0))))
  (check-equal? (scratch-registers '(scratch (native x5) (native x6)))
                '((native x5) (native x6)))
  (check-equal? (scratch-registers '(scratch)) '()))

(test-case "lookup is plain assoc / hash"
  (check-equal? (allocation-location register-allocation '($ a))
                '(native x10))
  (check-equal? (allocation-location register-allocation '($ b))
                '(native x11))
  (check-equal? (hash-ref (allocation-table spill-allocation) '($ b))
                '(slot 0)))

;; ---------------------------------------------------------------------------
;; 合法表
;; ---------------------------------------------------------------------------

(test-case "stack-local allocation passes"
  (check-allocation-ok stack-local-virtual stack-local-allocation))

(test-case "all registers pass"
  (check-allocation-ok minimal-virtual register-allocation))

(test-case "spill to slot passes"
  (check-allocation-ok minimal-virtual spill-allocation))

(test-case "scratch is a separate output"
  (check-allocation-ok minimal-virtual register-allocation spill-scratch))

(test-case "empty allocation is valid for a function with no vregs"
  (check-allocation-ok
   '(func (main)
      (vregs)
      (entry b0)
      (block b0
        (term (return 0))))
   '(allocation)))

(test-case "unused declared vreg may be absent"
  (define func
    '(func (main)
       (vregs
         (($ a) (b64))
         (($ unused) (b64)))
       (entry b0)
       (block b0
         (term (return ($ a))))))
  (check-allocation-ok func
                       '(allocation
                          (($ a) (native x10)))))

(test-case "address-taken vreg may be absent from code but still needs a slot"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken)))
       (entry b0)
       (block b0
         (term (return 0)))))
  (check-allocation-error
   #rx"address-taken vreg .* has no allocation entry"
   func
   '(allocation))
  (check-allocation-ok func
                       '(allocation
                          (($ x) (slot 0)))))

(test-case "address-taken vreg must be in a slot"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken))
         (($ p) (ptr)))
       (entry b0)
       (block b0
         (addr ($ p) ($ x))
         (term (return ($ p))))))
  (check-allocation-ok func
                       '(allocation
                          (($ x) (slot 0))
                          (($ p) (native x10))))
  (check-allocation-error
   #rx"must be allocated to \\(slot n\\)"
   func
   '(allocation
      (($ x) (native x10))
      (($ p) (native x11)))))

;; ---------------------------------------------------------------------------
;; 缺项 / 多项 / 非法 key
;; ---------------------------------------------------------------------------

(test-case "used vreg without entry"
  (check-allocation-error
   #rx"used vreg .* has no allocation entry"
   minimal-virtual
   '(allocation
      (($ a) (native x10))
      (($ b) (native x11)))))

(test-case "undeclared vreg in allocation"
  (check-allocation-error
   #rx"undeclared vreg"
   minimal-virtual
   '(allocation
      (($ a) (native x10))
      (($ b) (native x11))
      (($ t) (native x12))
      (($ z) (native x13)))))

(test-case "duplicate key"
  (check-allocation-error
   #rx"more than one allocation entry"
   minimal-virtual
   '(allocation
      (($ a) (native x10))
      (($ a) (native x11))
      (($ b) (native x12))
      (($ t) (native x13)))))

(test-case "malformed allocation and entries"
  (check-allocation-error
   #rx"malformed allocation"
   minimal-virtual
   '(allocation (($ a) (reg x10))))
  (check-allocation-error
   #rx"malformed allocation"
   minimal-virtual
   '(allocation (#f (native x10))))
  (check-allocation-error
   #rx"malformed allocation"
   minimal-virtual
   (list 'allocation (cons '($ a) '(native x10)))))

;; ---------------------------------------------------------------------------
;; pin / reserve
;; ---------------------------------------------------------------------------

(test-case "pin must be honored"
  (define func
    '(func (main)
       (vregs
         (($ a) (b64)))
       (alloc
         (pin ($ a) (native x10)))
       (entry b0)
       (block b0
         (term (return ($ a))))))
  (check-allocation-ok func
                       '(allocation
                          (($ a) (native x10))))
  (check-allocation-error
   #rx"pinned vreg .* must be allocated"
   func
   '(allocation
      (($ a) (native x11)))))

(test-case "reserved register is not for ordinary allocation"
  (define func
    '(func (main)
       (vregs
         (($ a) (b64)))
       (alloc
         (reserve (native x5)))
       (entry b0)
       (block b0
         (term (return ($ a))))))
  (check-allocation-error
   #rx"uses reserved register"
   func
   '(allocation
      (($ a) (native x5))))
  (check-allocation-ok func
                       '(allocation
                          (($ a) (native x6)))))

(test-case "an explicit pin may use a reserved register"
  (define func
    '(func (main)
       (vregs
         (($ a) (b64)))
       (alloc
         (reserve (native x5))
         (pin ($ a) (native x5)))
       (entry b0)
       (block b0
         (term (return ($ a))))))
  (check-allocation-ok func
                       '(allocation
                          (($ a) (native x5)))))

;; ---------------------------------------------------------------------------
;; scratch
;; ---------------------------------------------------------------------------

(test-case "scratch shape is checked when supplied"
  (check-allocation-error
   #rx"malformed scratch"
   minimal-virtual
   register-allocation
   '(scratch (native a0)))
  (check-allocation-error
   #rx"malformed scratch"
   minimal-virtual
   register-allocation
   '(scratch (slot 0))))
