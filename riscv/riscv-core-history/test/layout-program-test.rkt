#lang racket
;;; test/layout-program-test.rkt
;;;
;;; program-level layout：函数偏移、call-target 近/远形式、encode-program。

(require rackunit
         racket/list
         "../ir/cfg.rkt"
         "../layout/plan.rkt"
         "../layout/relax.rkt"
         "../layout/program.rkt"
         "../encode/encode.rkt")

(define frame16
  '(frame
     (size 16)
     (header 16)
     (outgoing 0)
     (align 16)
     (slots)))

(define (machine-func name blocks)
  (append (list 'func name frame16 '(scratch) '(entry b0))
          blocks))

(define (bytes->words bs)
  (for/list ([i (in-range 0 (bytes-length bs) 4)])
    (for/fold ([w 0]) ([j (in-range 4)])
      (bitwise-ior w
                   (arithmetic-shift (bytes-ref bs (+ i j)) (* 8 j))))))

(define (section-by-name program name)
  (findf (lambda (section)
           (equal? (function-section-name section) name))
         (program-layout-sections program)))

;; ---------------------------------------------------------------------------
;; near call
;; ---------------------------------------------------------------------------

(test-case "near call becomes call-jal and shrinks to 4 bytes"
  (define main
    (machine-func '(main)
                  '((block b0
                      (call-target (global (f)))
                      (term (return))))))
  (define f
    (machine-func '(f)
                  '((block b0
                      (term (return))))))
  (define program (layout-program (list main f)))

  (check-equal? (program-layout-size program) 12)
  (check-equal? (hash-ref (program-layout-bases program) '(main)) 0)
  (check-equal? (hash-ref (program-layout-bases program) '(f)) 8)
  (check-equal?
   (function-section-items (section-by-name program '(main)))
   '((label b0)
     (call-jal 8)
     (jalr (native x0) (native x1) 0)))
  (check-equal?
   (function-section-items (section-by-name program '(f)))
   '((label b0)
     (jalr (native x0) (native x1) 0)))

  (define enc (encode-program program))
  (check-equal? (encoded-program-size enc) 12)
  (check-equal? (map encoded-section-base (encoded-program-sections enc))
                '(0 8))
  (check-equal? (bytes->words (encoded-program-bytes enc))
                (list #x008000ef #x00008067 #x00008067)))

(test-case "call from the second function uses a negative near offset"
  (define main
    (machine-func '(main)
                  '((block b0
                      (term (return))))))
  (define f
    (machine-func '(f)
                  '((block b0
                      (call-target (global (main)))
                      (term (return))))))
  (define program (layout-program (list main f)))
  ;; main: return 4B；f base = 4；call 的地址是 4，target 是 0。
  (check-equal? (program-layout-size program) 12)
  (check-equal?
   (function-section-items (section-by-name program '(f)))
   '((label b0)
     (call-jal -4)
     (jalr (native x0) (native x1) 0))))

(test-case "empty program is allowed"
  (define program (layout-program '()))
  (check-equal? (program-layout-size program) 0)
  (check-equal? (program-layout-sections program) '())
  (check-equal? (encoded-program-size (encode-program program)) 0))

;; ---------------------------------------------------------------------------
;; far call
;; ---------------------------------------------------------------------------

(test-case "far call becomes auipc + jalr"
  ;; target 刚好超过 JAL 的 1MiB 范围。
  (define main
    (machine-func '(main)
                  '((block b0
                      (call-target (global (f)))
                      (term (return))))))
  (define filler-body
    (for/list ([i (in-range 262141)])
      '(addi (native x5) (native x5) 1)))
  (define filler
    (machine-func '(filler)
                  (list (list* 'block 'b0
                               (append filler-body
                                       (list '(term (return))))))))
  (define f
    (machine-func '(f)
                  '((block b0
                      (term (return))))))
  (define program (layout-program (list main filler f)))
  (define main-items
    (function-section-items (section-by-name program '(main))))

  (check-equal? (car main-items) '(label b0))
  (check-equal? (car (cadr main-items)) 'auipc)
  (check-equal? (car (caddr main-items)) 'jalr)
  (check-equal? (last main-items) '(jalr (native x0) (native x1) 0))
  (check-equal? (function-section-size (section-by-name program '(main))) 12)
  (check-true (> (program-layout-size program) (* 1024 1024)))

  (define enc (encode-program program))
  (define first-two (bytes->words (subbytes (encoded-program-bytes enc) 0 8)))
  (check-equal? (map (lambda (w) (bitwise-and w #x7f)) first-two)
                (list #x17 #x67)))

;; ---------------------------------------------------------------------------
;; errors
;; ---------------------------------------------------------------------------

(test-case "undefined call target is rejected"
  (define main
    (machine-func '(main)
                  '((block b0
                      (call-target (global (missing)))
                      (term (return))))))
  (check-exn #rx"undefined function"
             (lambda () (layout-program (list main)))))

(test-case "duplicate function is rejected"
  (define a (machine-func '(main) '((block b0 (term (return))))))
  (check-exn #rx"defined twice"
             (lambda () (layout-program (list a a)))))

(test-case "unlowered call is rejected before program layout"
  (define main
    (machine-func '(main)
                  '((block b0
                      (call (native x10) (global (f)))
                      (term (return))))))
  (define f (machine-func '(f) '((block b0 (term (return))))))
  (check-exn #rx"unlowered call"
             (lambda () (layout-program (list main f)))))

(test-case "encode-layout still rejects symbolic call-target"
  (define main
    (machine-func '(main)
                  '((block b0
                      (call-target (global (f)))
                      (term (return))))))
  (define cfg (build-cfg main))
  (define plan (plan-layout cfg))
  (define layout (layout-func main plan))
  (check-exn #rx"call-target requires program layout"
             (lambda () (encode-layout layout))))
