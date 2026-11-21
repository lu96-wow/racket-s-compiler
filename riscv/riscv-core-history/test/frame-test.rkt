#lang racket
;;; test/frame-test.rkt
;;;
;;; frame-layout：slot 偏移、frame size、header/outgoing、对齐。

(require rackunit
         "../ir/frame.rkt"
         "../ir/allocation.rkt"
         "../examples/minimal.rkt"
         "../examples/allocation.rkt"
         "../examples/stack-local.rkt")

(define (check-frame-ok func allocation [expected #f])
  (define frame (frame-layout func allocation))
  (check-true (frame-form? frame))
  (when expected
    (check-equal? frame expected))
  frame)

;; ---------------------------------------------------------------------------
;; 基础
;; ---------------------------------------------------------------------------

(test-case "stack-local example: explicit addr + slot + frame"
  (define frame (frame-layout stack-local-virtual stack-local-allocation))
  (check-equal? frame stack-local-frame)
  (check-equal? (frame-slot-offset frame 0) 24)
  (check-equal? (frame-size frame) 32))

(test-case "no slots still has the default header"
  (define frame (check-frame-ok minimal-virtual register-allocation))
  (check-equal? (frame-size frame) 16)
  (check-equal? (frame-slot-offset frame 0) #f)
  (check-equal? frame
                '(frame
                   (size 16)
                   (header 16)
                   (outgoing 0)
                   (align 16)
                   (slots))))

(test-case "one spill slot uses type size and alignment"
  (define frame
    (check-frame-ok minimal-virtual spill-allocation))
  (check-equal? (frame-size frame) 32)
  (check-equal? (frame-slot-offset frame 0) 17)
  (check-equal? frame
                '(frame
                   (size 32)
                   (header 16)
                   (outgoing 0)
                   (align 16)
                   (slots
                     (slot 0 (offset 17) (size 1) (align 1))))))

;; ---------------------------------------------------------------------------
;; 多 slot / 对齐 / sharing
;; ---------------------------------------------------------------------------

(test-case "multiple slots are aligned in slot-index order"
  (define func
    '(func (main)
       (vregs
         (($ a) (b8) (address-taken))
         (($ b) (b64) (address-taken) (align 16))
         (($ c) (b32) (address-taken)))
       (entry b0)
       (block b0
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ a) (slot 0))
       (($ b) (slot 1))
       (($ c) (slot 2))))
  (define frame (frame-layout func allocation))
  (check-equal? (frame-size frame) 48)
  (check-equal? (frame-slot-offset frame 0) 17)
  (check-equal? (frame-slot-offset frame 1) 40)
  (check-equal? (frame-slot-offset frame 2) 44)
  (check-equal? frame
                '(frame
                   (size 48)
                   (header 16)
                   (outgoing 0)
                   (align 16)
                   (slots
                     (slot 0 (offset 17) (size 1) (align 1))
                     (slot 1 (offset 40) (size 8) (align 16))
                     (slot 2 (offset 44) (size 4) (align 4))))))

(test-case "two vregs may share a slot; layout takes max size/align"
  (define func
    '(func (main)
       (vregs
         (($ a) (b8) (address-taken))
         (($ b) (b64) (address-taken)))
       (entry b0)
       (block b0
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ a) (slot 0))
       (($ b) (slot 0))))
  (define frame (frame-layout func allocation))
  (check-equal? (frame-slot-offset frame 0) 24)
  (check-equal? (frame-size frame) 32)
  (check-equal? (length (frame-slots frame)) 1))

(test-case "outgoing args live below the slots"
  (define func
    '(func (main)
       (vregs
         (($ a) (b64) (address-taken)))
       (entry b0)
       (block b0
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ a) (slot 0))))
  (define frame (frame-layout func allocation #:outgoing-size 8))
  (check-equal? (frame-slot-offset frame 0) 24)
  (check-equal? (frame-size frame) 32)
  (check-equal? frame
                '(frame
                   (size 32)
                   (header 16)
                   (outgoing 8)
                   (align 16)
                   (slots
                     (slot 0 (offset 24) (size 8) (align 8))))))

(test-case "xlen decides pointer size"
  (define func
    '(func (main)
       (vregs
         (($ p) (ptr) (address-taken)))
       (entry b0)
       (block b0
         (term (return 0)))))
  (define allocation
    '(allocation
       (($ p) (slot 0))))
  (define frame32 (frame-layout func allocation #:xlen 32))
  (define frame64 (frame-layout func allocation #:xlen 64))
  (check-equal? (frame-slot-offset frame32 0) 20)
  (check-equal? (frame-slot-offset frame64 0) 24)
  (check-equal? (frame-size frame32) 32)
  (check-equal? (frame-size frame64) 32))

;; ---------------------------------------------------------------------------
;; 错误
;; ---------------------------------------------------------------------------

(test-case "address-taken vreg must not be in a register"
  (define func
    '(func (main)
       (vregs
         (($ x) (b64) (address-taken)))
       (entry b0)
       (block b0
         (term (return 0)))))
  (check-exn #rx"address-taken vreg .* must be allocated to a slot"
             (lambda ()
               (frame-layout func
                             '(allocation
                                (($ x) (native x10)))))))

(test-case "malformed allocation is rejected"
  (check-exn #rx"malformed allocation"
             (lambda ()
               (frame-layout minimal-virtual
                             '(allocation
                                (($ a) (reg x10)))))))

(test-case "bad frame parameters are rejected"
  (check-exn exn:fail?
             (lambda ()
               (frame-layout minimal-virtual register-allocation #:xlen 63)))
  (check-exn exn:fail?
             (lambda ()
               (frame-layout minimal-virtual register-allocation #:frame-align 12))))
