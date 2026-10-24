#lang racket/base

;; ============================================================
;; Runtime generated-package layout
;;
;; This is the single runtime source of truth for where generated
;; modules live. Build-time output layout is defined in binary-build/paths.rkt;
;; tests verify that the two views point at the same files.
;;
;; generated/
;;   lib/                <- this file lives here
;;   gen/riscv/...       <- generated modules
;; ============================================================

(require racket/path
         racket/runtime-path)

(define-runtime-path self-path "layout.rkt")
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

(define (info-dir)
  (build-path package-root "gen" "riscv" "info"))

(define (instruction-info-path extension)
  (path->string
   (build-path (info-dir) (extension-module-filename extension))))

(define (extensions-path)
  (build-path (info-dir) "extensions.rkt"))

(define (instruction-extensions-path)
  (build-path (info-dir) "instruction_extensions.rkt"))

(provide package-root
         extension-module-filename
         raw-instruction-path
         rebuilt-instruction-path
         instruction-info-path
         extensions-path
         instruction-extensions-path)
