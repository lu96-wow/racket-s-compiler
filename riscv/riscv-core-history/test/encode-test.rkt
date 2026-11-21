#lang racket
;;; test/encode-test.rkt
;;;
;;; layout-result -> little-endian bytes。

(require rackunit
         "../encode/encode.rkt"
         "../layout/relax.rkt"
         "../layout/plan.rkt")

(define frame16
  '(frame
     (size 16)
     (header 16)
     (outgoing 0)
     (align 16)
     (slots)))

(define (machine-func blocks)
  (append (list 'func '(main) frame16 '(scratch) '(entry b0))
          blocks))

(define (make-plan order fallthrough)
  (layout-plan '(main) 'b0 order
               (for/hash ([pair (in-list fallthrough)])
                 (values (car pair) (cadr pair)))))

(define (layout+encode func plan)
  (encode-layout (layout-func func plan)))

(define (bytes->words bs)
  (for/list ([i (in-range 0 (bytes-length bs) 4)])
    (for/fold ([w 0]) ([j (in-range 4)])
      (bitwise-ior w
                   (arithmetic-shift (bytes-ref bs (+ i j)) (* 8 j))))))

;; ---------------------------------------------------------------------------
;; 基础
;; ---------------------------------------------------------------------------

(test-case "addi + return"
  (define func
    (machine-func
     '((block b0
         (addi (native x10) (native x0) 1)
         (term (return))))))
  (define plan (make-plan '(b0) '()))
  (define enc (layout+encode func plan))
  (check-equal? (encoded-size enc) 8)
  (check-equal? (bytes->words (encoded-bytes enc))
                (list #x00100513 #x00008067))
  (check-equal? (hash-ref (encoded-labels enc) 'b0) 0))

(test-case "branch and labels"
  (define func
    (machine-func
     '((block b0
         (term (branch (eq (native x12) 0) b2 b1)))
       (block b1
         (term (return)))
       (block b2
         (term (return))))))
  (define plan (make-plan '(b0 b1 b2) '((b0 b1))))
  (define enc (layout+encode func plan))
  (check-equal? (encoded-size enc) 12)
  (check-equal? (bytes->words (encoded-bytes enc))
                (list #x00060463 #x00008067 #x00008067))
  (check-equal? (hash-ref (encoded-labels enc) 'b0) 0)
  (check-equal? (hash-ref (encoded-labels enc) 'b1) 4)
  (check-equal? (hash-ref (encoded-labels enc) 'b2) 8))

(test-case "jump"
  (define func
    (machine-func
     '((block b0
         (term (jump b2)))
       (block b1
         (term (return)))
       (block b2
         (term (return))))))
  (define plan (make-plan '(b0 b1 b2) '()))
  (define enc (layout+encode func plan))
  (check-equal? (encoded-size enc) 12)
  (check-equal? (bytes->words (encoded-bytes enc))
                (list #x0080006f #x00008067 #x00008067))
  (check-equal? (hash-ref (encoded-labels enc) 'b2) 8))

(test-case "trap"
  (define func
    (machine-func
     '((block b0
         (term (trap))))))
  (define plan (make-plan '(b0) '()))
  (define enc (layout+encode func plan))
  (check-equal? (encoded-size enc) 4)
  (check-equal? (bytes->words (encoded-bytes enc))
                (list #x00100073)))

;; ---------------------------------------------------------------------------
;; 错误
;; ---------------------------------------------------------------------------

(test-case "call-target needs global layout"
  (define func
    (machine-func
     '((block b0
         (call-target (global (f)))
         (term (return))))))
  (define plan (make-plan '(b0) '()))
  (check-exn #rx"call-target requires program layout"
             (lambda () (layout+encode func plan))))

(test-case "unknown native instruction is rejected by riscv-asm"
  (define func
    (machine-func
     '((block b0
         (definitely-not-an-instruction (native x10))
         (term (return))))))
  (define plan (make-plan '(b0) '()))
  (check-exn exn:fail?
             (lambda () (layout+encode func plan))))
