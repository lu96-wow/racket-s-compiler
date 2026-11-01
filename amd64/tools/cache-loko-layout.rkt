#lang racket
;;; amd64/tools/cache-loko-layout.rkt
;;;
;;; 跑一次昂贵的 Loko 前端 + 编译器流水线，把 bound-layout/symbols/image-plan
;;; 缓存成 s-expression。之后的 ELF/编码实验直接读缓存，不再重跑
;;; analyze/dce/layout/relax。
;;;
;;; 用法：
;;;   racket tools/cache-loko-layout.rkt <dump.sexp> <cache.sexp>

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
 #:program "cache-loko-layout"
 #:args (dump-path cache-path [flow-name "loko-near"])
 (define target (hash 'arch 'amd64))
 (define source
   (list 'loko-source
         (cons 'text (read-items dump-path))
         '(data)))
 (define started (current-inexact-milliseconds))
 (define flow (string->symbol flow-name))
 (define context (run-flow target flow (hash 'loko-source source)))
 (printf "pipeline: ~ams\n"
         (round (- (current-inexact-milliseconds) started)))
 (define bound (hash-ref context 'bound-layout))
 (define image-plan (ir-list (hash-ref context 'loko-ir) 'image-plan))
 (call-with-output-file cache-path #:exists 'replace
   (lambda (out)
     (write (list 'loko-layout-cache
                  (list 'bound-layout bound)
                  (list 'image-plan image-plan))
            out)))
 (printf "cached ~a\n" cache-path))
