#lang racket
;;; test/asm-code-test.rkt
;;;
;;; inline asm：code 规范化、materialize、layout、encode。

(require rackunit
         racket/list
         "../asm/code.rkt"
         "../core/sexp.rkt"
         "../ir/allocate.rkt"
         "../ir/allocation.rkt"
         "../ir/materialize.rkt"
         "../ir/call-plan.rkt"
         "../ir/frame.rkt"
         "../ir/lower.rkt"
         "../ir/call-lower.rkt"
         "../ir/verify-machine.rkt"
         "../layout/program.rkt"
         "../encode/encode.rkt"
         "../examples/asm.rkt")

(define (bytes->words bs)
  (for/list ([i (in-range 0 (bytes-length bs) 4)])
    (for/fold ([w 0]) ([j (in-range 4)])
      (bitwise-ior w
                   (arithmetic-shift (bytes-ref bs (+ i j)) (* 8 j))))))

(define (contains-vreg? x)
  (cond
    [(vreg? x) #t]
    [(list? x) (ormap contains-vreg? x)]
    [else #f]))

(define (modeless-section-labels enc)
  (for/list ([section (in-list (encoded-program-sections enc))])
    (sort (hash-keys (encoded-section-labels section)) symbol<?)))

;; ---------------------------------------------------------------------------
;; asm/code
;; ---------------------------------------------------------------------------

(test-case "asm code normalizes local labels and control"
  (define l (normalize-asm-code
             '((label loop)
               (add (native x12) (native x10) (native x11))
               (bne loop (native x10) (native x11))
               (j end)
               (label end))))
  (check-equal? (asm-code-size (asm-code-layout-items l)) 12)
  (check-equal? (hash-ref (asm-code-layout-labels l) 'loop) 0)
  (check-equal? (hash-ref (asm-code-layout-labels l) 'end) 12)
  (check-equal?
   (asm-code-layout-items l)
   '((label loop)
     (add (native x12) (native x10) (native x11))
     (bne loop (native x10) (native x11))
     (jal (native x0) end)
     (label end))))

(test-case "asm code target must be local"
  (check-exn #rx"not defined in code"
             (lambda ()
               (normalize-asm-code '((j missing))))))

(test-case "asm code duplicate label is rejected"
  (check-exn #rx"asm label .* is defined twice"
             (lambda ()
               (normalize-asm-code '((label x) (label x))))))

;; ---------------------------------------------------------------------------
;; full pipeline
;; ---------------------------------------------------------------------------

(test-case "inline asm goes through the whole pipeline"
  (define forbidden
    '((native x1) (native x2) (native x8) (native x10) (native x11)))
  (define-values (allocation scratch)
    (allocate-func asm-add #:scratch-budget 2 #:forbidden forbidden))

  ;; clobber x5 不能被普通 vreg 使用。
  (for ([(vreg loc) (in-hash (allocation-table allocation))])
    (check-false (equal? loc '(native x5))))

  (define machine (materialize-func asm-add allocation #:scratch scratch))
  (check-false (contains-vreg? machine))
  (check-true (ormap (lambda (op) (and (form? op) (eq? (car op) 'asm-code)))
                     (append* (for/list ([block (in-list (filter (lambda (x)
                                                                   (and (form? x) (eq? (car x) 'block)))
                                                                 (cddr machine)))])
                                (cddr block)))))

  (define plan (plan-calls machine))
  (define frame (frame-layout asm-add allocation
                              #:outgoing-size (call-plan-outgoing-size plan)))
  (define lowered (lower-func machine frame #:scratch scratch))
  (define called (lower-calls lowered frame #:scratch scratch))
  (verify-machine (list called))

  (define program (layout-program (list called)))
  (define enc (encode-program program))
  (check-true (> (encoded-program-size enc) 0))
  (check-equal? (modulo (encoded-program-size enc) 4) 0)

  ;; asm-code 的 branch 仍然落在 section 内；函数仍能编码。
  (check-equal? (modeless-section-labels enc)
                '((b0))))
