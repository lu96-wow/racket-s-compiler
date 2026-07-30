#lang racket

(require "asm.rkt"
         racket/match)

;; ============================================================
;; 入口：解析 (asm word-size (ext...) ...) → 调核心
;; ============================================================

(define (assemble-sexp sexp)
  (match sexp
    [`(asm ,word-size ,exts ,body ...)
     (unless (memq word-size '(rv32 rv64))
       (error 'asm "word-size must be rv32 or rv64, got: ~a" word-size))
     (unless (and (list? exts) (andmap symbol? exts))
       (error 'asm "extensions must be (ext...), got: ~a" exts))
     (define items (for/list ([i (in-list body)])
                     (match i
                       [`(label ,(? symbol? n)) (asm-label n)]
                       [`(li ,(? symbol? r) ,(? exact-integer? v)) (asm-insn 'li (list r v))]
                       [`(,(? symbol? m) ,args ...) (asm-insn m args)]
                       [_ (error 'asm "unexpected item: ~a" i)])))
     (assemble items word-size exts)]
    [_ (error 'asm "expected (asm rv32|rv64 (ext...) ...)")]))

(define (assemble-file path)
  (call-with-input-file path
    (λ (in)
      (let loop ()
        (define s (read in))
        (if (eof-object? s) #"" (assemble-sexp s))))))

(provide assemble-sexp assemble-file)
