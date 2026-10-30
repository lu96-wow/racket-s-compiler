#lang racket
;;; run.rkt -- 按文件跑完整测试套件

(require racket/list
         racket/path
         racket/string)

(define test-files
  '("sexp-test.rkt"
    "expand-data-test.rkt"
    "flatten-test.rkt"
    "expand-pseudo-test.rkt"
    "analyze-test.rkt"
    "dce-test.rkt"
    "layout-test.rkt"
    "bind-labels-test.rkt"
    "relax-test.rkt"
    "encode-test.rkt"
    "flow-test.rkt"
    "integration-test.rkt"))

(define here
  (or (path-only (find-system-path 'run-file))
      (current-directory)))

(define racket-exe
  (or (find-executable-path "racket") "racket"))

(define failures '())
(define (report! file ok?)
  (printf "~a ~a\n" (if ok? "PASS" "FAIL") file)
  (unless ok? (set! failures (cons file failures))))

(for ([file (in-list test-files)])
  (define path (build-path here file))
  (printf "== ~a\n" file)
  (define-values (proc _out _in _err)
    (subprocess #f #f #f racket-exe (path->string path)))
  (subprocess-wait proc)
  (define code (subprocess-status proc))
  (report! file (zero? code)))

(newline)
(if (null? failures)
    (printf "all ~a test files: ok\n" (length test-files))
    (begin
      (printf "failed: ~a\n" (string-join (reverse failures) ", "))
      (exit 1)))
