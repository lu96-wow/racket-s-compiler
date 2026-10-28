#lang racket/base

;; ============================================================
;; riscv-compiler CLI（底层 S-expression 链）
;;
;; 用法：
;;   racket main.rkt [asm.sexpr]
;;   racket main.rkt --verbose examples/basic-asm.sexpr
;; ============================================================

(require racket/cmdline
         racket/pretty
         racket/runtime-path
         "compile-asm.rkt")

(define-runtime-path default-example "examples/basic-asm.sexpr")

(define source-path #f)
(define verbose? #f)

(command-line
 #:program "riscv-compiler"
 #:once-each
 [("-v" "--verbose")
  "Show CFG, liveness, interference, coloring, and layout"
  (set! verbose? #t)]
 #:args args
 (cond
   [(null? args) (set! source-path default-example)]
   [(null? (cdr args)) (set! source-path (car args))]
   [else (error 'riscv-compiler "expected at most one source file")]))

(define source
  (call-with-input-file source-path
    (lambda (in)
      (define datum (read in))
      (when (eof-object? datum)
        (error 'riscv-compiler "empty source file: ~a" source-path))
      datum)))

(define-values (name program asm cfg live interference regmap coloring labels resolved)
  (compile-asm source))

(pretty-write program)

(when verbose?
  (eprintf "; name: ~a\n" name)
  (eprintf "; optimized asm: ~s\n" asm)
  (eprintf "; cfg: ~s\n" cfg)
  (eprintf "; liveness: ~s\n" live)
  (eprintf "; interference: ~s\n" interference)
  (eprintf "; regmap: ~s\n" regmap)
  (eprintf "; coloring: ~s\n" coloring)
  (eprintf "; labels: ~s\n" labels)
  (eprintf "; resolved:\n")
  (for ([instruction (in-list resolved)])
    (eprintf ";   ~s\n" instruction)))
