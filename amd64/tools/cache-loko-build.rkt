#lang racket
;;; amd64/tools/cache-loko-build.rkt
;;;
;;; 跑一次昂贵的 Loko 前端 + 编译器流水线，把 build/symbols/image-plan
;;; 缓存成 s-expression。之后的 ELF/编码实验直接读缓存，不再重跑
;;; analyze/dce/layout/relax。
;;;
;;; 用法：
;;;   racket tools/cache-loko-build.rkt <dump.sexp> <cache.sexp>

(require racket/cmdline
         (file "../compiler/flow/flow.rkt")
         (only-in (file "../loko-compatibility/ir.rkt") ir-list))

(define (read-items path)
  (call-with-input-file path
    (lambda (in)
      (let loop ([items '()])
        (define x (read in))
        (if (eof-object? x) (reverse items) (loop (cons x items)))))))

(command-line
 #:program "cache-loko-build"
 #:args (dump-path cache-path)
 (define target (hash 'arch 'amd64))
 (define source
   (list 'loko-source
         (cons 'text (read-items dump-path))
         '(data)))
 (define started (current-inexact-milliseconds))
 (define context (run-flow target 'loko (hash 'loko-source source)))
 (printf "pipeline: ~ams\n"
         (round (- (current-inexact-milliseconds) started)))
 (define build (hash-ref context 'build))
 (define symbols (cdr (assq 'symbols (hash-ref context 'bound-layout))))
 (define image-plan (ir-list (hash-ref context 'loko-ir) 'image-plan))
 (call-with-output-file cache-path #:exists 'replace
   (lambda (out)
     (write (list 'loko-build-cache
                  (list 'build build)
                  (list 'symbols symbols)
                  (list 'image-plan image-plan))
            out)))
 (printf "cached ~a\n" cache-path))
