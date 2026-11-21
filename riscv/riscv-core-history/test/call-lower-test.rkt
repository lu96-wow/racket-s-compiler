#lang racket
;;; test/call-lower-test.rkt
;;;
;;; call-lower：prologue / call sequence / return sequence / epilogue。

(require rackunit
         "../ir/call-lower.rkt")

(define frame16
  '(frame
     (size 16)
     (header 16)
     (outgoing 0)
     (align 16)
     (slots)))

(define frame32-out16
  '(frame
     (size 32)
     (header 16)
     (outgoing 16)
     (align 16)
     (slots)))

(define scratch2 '((native x5) (native x6)))

(define (call-func body)
  (list 'func '(main)
        frame16
        (cons 'scratch scratch2)
        '(entry b0)
        (list* 'block 'b0 body)))

(define (first-block-lowered func)
  (list-ref func 5))

(define (check-no-call x)
  (cond
    [(and (form? x) (eq? (car x) 'call))
     (error 'test "unlowered call remains: ~e" x)]
    [(list? x) (for-each check-no-call x)]
    [else (void)]))

(define (form? x) (and (pair? x) (list? x)))

;; ---------------------------------------------------------------------------
;; prologue / call / return
;; ---------------------------------------------------------------------------

(test-case "call with no args and return x10"
  (define func
    (call-func
     '((call (native x10) (global (f)))
       (term (return (native x10))))))
  (define lowered (lower-calls func frame16))
  (check-no-call lowered)
  (check-equal?
   lowered
   '(func (main)
      (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
      (scratch (native x5) (native x6))
      (entry b0)
      (block b0
        (addi (native x5) (native x8) 0)
        (addi (native x8) (native x2) 0)
        (addi (native x2) (native x2) -16)
        (sd -8 (native x8) (native x1))
        (sd -16 (native x8) (native x5))
        (call-target (global (f)))
        (ld (native x1) (native x8) -8)
        (ld (native x5) (native x8) -16)
        (addi (native x2) (native x8) 0)
        (addi (native x8) (native x5) 0)
        (term (return))))))

(test-case "call writes native and integer args to outgoing area"
  (define func
    '(func (main)
       (frame (size 32) (header 16) (outgoing 16) (align 16) (slots))
       (scratch (native x5) (native x6))
       (entry b0)
       (block b0
         (call (native x10) (global (f)) (native x11) 42)
         (term (return (native x10))))))
  (check-equal?
   (lower-calls func frame32-out16)
   '(func (main)
      (frame (size 32) (header 16) (outgoing 16) (align 16) (slots))
      (scratch (native x5) (native x6))
      (entry b0)
      (block b0
        (addi (native x5) (native x8) 0)
        (addi (native x8) (native x2) 0)
        (addi (native x2) (native x2) -32)
        (sd -8 (native x8) (native x1))
        (sd -16 (native x8) (native x5))
        (sd 0 (native x2) (native x11))
        (addi (native x5) (native x0) 42)
        (sd 8 (native x2) (native x5))
        (call-target (global (f)))
        (ld (native x1) (native x8) -8)
        (ld (native x5) (native x8) -16)
        (addi (native x2) (native x8) 0)
        (addi (native x8) (native x5) 0)
        (term (return))))))

(test-case "call-lower does not clobber a materialized slot argument"
  (define func
    '(func (main)
       (frame (size 32) (header 16) (outgoing 16) (align 16) (slots))
       (scratch (native x5) (native x6))
       (entry b0)
       (block b0
         (call (native x10) (global (f)) 42 (native x5))
         (term (return (native x10))))))
  (define lowered (lower-calls func frame32-out16))
  (define ops (cddr (first-block-lowered lowered)))
  (check-true (and (member '(addi (native x6) (native x0) 42) ops) #t))
  (check-false (member '(addi (native x5) (native x0) 42) ops))
  (check-true (and (member '(sd 0 (native x2) (native x6)) ops) #t))
  (check-true (and (member '(sd 8 (native x2) (native x5)) ops) #t)))

(test-case "not enough scratch for an integer arg next to a slot arg"
  (define func
    '(func (main)
       (frame (size 32) (header 16) (outgoing 16) (align 16) (slots))
       (entry b0)
       (block b0
         (call (native x10) (global (f)) 42 (native x5))
         (term (return (native x10))))))
  (check-exn #rx"not enough scratch"
             (lambda ()
               (lower-calls func frame32-out16 #:scratch '((native x5))))))

(test-case "call dst other than x10 gets a move"
  (define func
    '(func (main)
       (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
       (scratch (native x5) (native x6))
       (entry b0)
       (block b0
         (call (native x12) (global (f)))
         (term (return (native x12))))))
  (define lowered (lower-calls func frame16))
  (check-not-false (member '(addi (native x12) (native x10) 0)
                      (cddr (first-block-lowered lowered)))))

(test-case "return x11 moves to x10"
  (define func
    (call-func
     '((call (native x10) (global (f)))
       (term (return (native x11))))))
  (define lowered (lower-calls func frame16))
  (check-not-false (member '(addi (native x10) (native x11) 0)
                      (cddr (first-block-lowered lowered)))))

(test-case "return integer loads x10"
  (define func
    (call-func
     '((call (native x10) (global (f)))
       (term (return 7)))))
  (define lowered (lower-calls func frame16))
  (check-not-false (member '(addi (native x10) (native x0) 7)
                      (cddr (first-block-lowered lowered)))))

;; ---------------------------------------------------------------------------
;; large frame
;; ---------------------------------------------------------------------------

(test-case "large frame allocation uses second scratch"
  (define large-frame
    '(frame
       (size 4112)
       (header 16)
       (outgoing 0)
       (align 16)
       (slots)))
  (define func
    '(func (main)
       (frame (size 4112) (header 16) (outgoing 0) (align 16) (slots))
       (scratch (native x5) (native x6))
       (entry b0)
       (block b0
         (call (native x10) (global (f)))
         (term (return (native x10))))))
  (define lowered (lower-calls func large-frame))
  (define ops (cddr (first-block-lowered lowered)))
  (check-equal? (take ops 7)
                '((addi (native x5) (native x8) 0)
                  (addi (native x8) (native x2) 0)
                  (lui (native x6) 1)
                  (addi (native x6) (native x6) 16)
                  (sub (native x2) (native x2) (native x6))
                  (sd -8 (native x8) (native x1))
                  (sd -16 (native x8) (native x5)))))

;; ---------------------------------------------------------------------------
;; errors
;; ---------------------------------------------------------------------------

(test-case "no scratch for prologue"
  (define func
    '(func (main)
       (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
       (entry b0)
       (block b0
         (call (native x10) (global (f)))
         (term (return (native x10))))))
  (check-exn #rx"not enough scratch"
             (lambda () (lower-calls func frame16))))

(test-case "scratch cannot be a runtime-fixed register"
  (define func
    '(func (main)
       (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
       (scratch (native x10))
       (entry b0)
       (block b0
         (call (native x10) (global (f)))
         (term (return (native x10))))))
  (check-exn #rx"reserved by the runtime contract"
             (lambda () (lower-calls func frame16))))

(test-case "outgoing area must be large enough"
  (define func
    '(func (main)
       (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
       (scratch (native x5) (native x6))
       (entry b0)
       (block b0
         (call (native x10) (global (f)) (native x11))
         (term (return (native x10))))))
  (check-exn #rx"frame only reserves"
             (lambda () (lower-calls func frame16))))

(test-case "more than one return value"
  (define func
    (call-func
     '((call (native x10) (global (f)))
       (term (return (native x10) (native x11))))))
  (check-exn #rx"at most one return value"
             (lambda () (lower-calls func frame16))))

(test-case "global call argument needs address lowering"
  (define func
    '(func (main)
       (frame (size 32) (header 16) (outgoing 8) (align 16) (slots))
       (scratch (native x5) (native x6))
       (entry b0)
       (block b0
         (call (native x10) (global (f)) (global (d)))
         (term (return (native x10))))))
  (check-exn #rx"unsupported call argument"
             (lambda () (lower-calls func frame32-out16))))
