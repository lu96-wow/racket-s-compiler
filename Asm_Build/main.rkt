#lang racket

(require "asm.rkt"
         racket/match)

;; ============================================================
;; unit 解析: (space KB 4) → 4096, (space 4096) → 4096
;; ============================================================
(define (space-size form)
  (match form
    [(list (? exact-integer? n)) n]
    [(list (and unit (or 'KB 'MB 'GB)) (? exact-integer? n))
     (* n (case unit [(KB) 1024] [(MB) 1048576] [(GB) 1073741824]))]
    [_ #f]))

;; ============================================================
;; 入口
;; ============================================================
(define (assemble-sexp sexp)
  (match sexp
    [`(asm ,word-size ,exts ,body ...)
     (unless (memq word-size '(rv32 rv64))
       (error 'asm "word-size must be rv32 or rv64, got: ~a" word-size))
     (unless (and (list? exts) (andmap symbol? exts))
       (error 'asm "extensions must be (ext...), got: ~a" exts))
     (define items
       (for/list ([i (in-list body)])
         (match i
           [`(label ,(? symbol? n))   (asm-label n)]
           [`(li ,(? symbol? r) ,(? exact-integer? v))  (asm-insn 'li (list r v))]
           [`(space ,args ...)
   #:when (space-size args)
   (asm-space (space-size args))]
           [`(,(? symbol? m) ,args ...)  (asm-insn m args)]
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
