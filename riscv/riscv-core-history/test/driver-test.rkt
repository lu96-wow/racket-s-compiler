#lang racket
;;; test/driver-test.rkt
;;;
;;; 统一 driver：source -> frontend -> pipeline -> layout -> bytes。
;;; scratch budget 从 0 开始，不足则 +1 重跑。

(require rackunit
         racket/list
         "../driver/compile.rkt"
         "../ir/scratch.rkt"
         "../layout/program.rkt"
         "../encode/encode.rkt")

(define (simple-source)
  '((module (m)
      (provide (main))
      (func (main)
        (vregs (($ r) (b64)))
        (entry b0)
        (block b0
          (const ($ r) 7)
          (term (return ($ r))))))))

(define (call-source)
  '((module (m)
      (provide (main) (f))
      (func (f)
        (vregs (($ r) (b64)))
        (entry b0)
        (block b0
          (const ($ r) 42)
          (term (return ($ r)))))
      (func (main)
        (vregs (($ r) (b64)))
        (entry b0)
        (block b0
          (call ($ r) (global (f)))
          (term (return ($ r))))))))

(define (data-raw-source)
  '((module (m)
      (provide (main) (d) (start))
      (data (d)
        (align 8)
        (value 8 7))
      (raw (start)
        (addi (native x10) (native x0) 1)
        (j (start)))
      (func (main)
        (vregs (($ p) (ptr)))
        (entry b0)
        (block b0
          (addr ($ p) (global (d)))
          (term (return ($ p))))))))

(test-case "compile-source runs the whole pipeline with scratch feedback"
  (define result (compile-source (simple-source)))
  (check-true (> (bytes-length (compiled-program-bytes result)) 0))
  (check-equal? (compiled-program-scratch-budget result) 1)
  (check-equal? (compiled-program-exports result) '((m main)))
  (check-equal? (bytes-length (compiled-program-bytes result))
                (program-layout-size (compiled-program-layout result)))
  (check-equal? (map encoded-section-kind
                     (encoded-program-sections
                      (compiled-program-encoded result)))
                '(code)))

(test-case "compile-source resolves an internal call"
  (define result (compile-source (call-source)))
  (check-equal? (map encoded-section-kind
                     (encoded-program-sections
                      (compiled-program-encoded result)))
                '(code code))
  (define all-items
    (append* (for/list ([section (in-list (program-layout-sections
                                           (compiled-program-layout result)))]
                        #:when (function-section? section))
               (function-section-items section))))
  (check-true (ormap (lambda (item) (eq? (car item) 'call-jal)) all-items)))

(test-case "compile-source handles func + raw + data together"
  (define result (compile-source (data-raw-source)))
  (check-equal? (map encoded-section-kind
                     (encoded-program-sections
                      (compiled-program-encoded result)))
                '(code raw data))
  (define layout (compiled-program-layout result))
  (check-equal? (hash-ref (program-layout-bases layout) '(m d)) 64)
  (check-equal? (hash-ref (program-layout-bases layout) '(m start)) 52)
  (check-equal? (bytes-length (compiled-program-bytes result))
                (program-layout-size layout)))

(test-case "scratch feedback reports exhaustion at max budget"
  (check-exn scratch-exhausted?
             (lambda ()
               (compile-source (simple-source) #:max-scratch 0))))

(test-case "raw/data-only program needs no scratch"
  (define result
    (compile-source
     '((module (m)
         (provide (d) (start))
         (data (d) (align 8) (value 8 1))
         (raw (start)
           (addi (native x10) (native x0) 1)
           (j (start)))))))
  (check-equal? (compiled-program-scratch-budget result) 0)
  (check-equal? (map encoded-section-kind
                     (encoded-program-sections
                      (compiled-program-encoded result)))
                '(raw data)))

(test-case "compile-files handles required functions"
  (define files
    '((file a
        (module (a)
          (provide (f))
          (func (f)
            (vregs (($ r) (b64)))
            (entry b0)
            (block b0
              (const ($ r) 42)
              (term (return ($ r)))))))
      (file b
        (module (b)
          (provide (main))
          (require (a))
          (func (main)
            (vregs (($ r) (b64)))
            (entry b0)
            (block b0
              (call ($ r) (global (f)))
              (term (return ($ r)))))))))
  (define result (compile-files files))
  (check-equal? (compiled-program-exports result)
                '((a f) (b main)))
  (check-equal? (map encoded-section-kind
                     (encoded-program-sections
                      (compiled-program-encoded result)))
                '(code code)))
