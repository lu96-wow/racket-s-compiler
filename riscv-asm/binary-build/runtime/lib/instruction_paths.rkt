#lang racket/base

;; ============================================================
;; Runtime path helper copied into generated/lib/instruction_paths.rkt
;; ============================================================

(require racket/path
         racket/runtime-path)

(define-runtime-path self-path "instruction_paths.rkt")
(define package-root
  (simplify-path (build-path (path-only self-path) "..")))

(define (extension-module-filename extension)
  (unless (symbol? extension)
    (raise-argument-error 'extension-module-filename "symbol?" extension))
  (string-append (symbol->string extension) ".rkt"))

(define (instruction-path kind extension)
  (path->string
   (build-path package-root "gen" "riscv" "instruction" kind
               (extension-module-filename extension))))

(define (raw-instruction-path extension)
  (instruction-path "raw" extension))

(define (rebuilt-instruction-path extension)
  (instruction-path "rebuilt" extension))

(provide raw-instruction-path
         rebuilt-instruction-path)
