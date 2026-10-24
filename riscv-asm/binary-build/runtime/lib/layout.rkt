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
         racket/runtime-path
         "layout-spec.rkt")

(define-runtime-path self-path "layout.rkt")
(define package-root
  (simplify-path (build-path (path-only self-path) "..")))

(define (path-under-root parts)
  (apply build-path package-root parts))

(define (instruction-directory-parts kind)
  (case kind
    [("raw") raw-instruction-dir-parts]
    [("rebuilt") rebuilt-instruction-dir-parts]
    [else (error 'instruction-path "unknown instruction kind: ~a" kind)]))

(define (instruction-path kind extension)
  (path->string
   (path-under-root
    (append (instruction-directory-parts kind)
            (list (extension-module-filename extension))))))

(define (raw-instruction-path extension)
  (instruction-path "raw" extension))

(define (rebuilt-instruction-path extension)
  (instruction-path "rebuilt" extension))

(define (info-dir)
  (path-under-root info-dir-parts))

(define (instruction-info-path extension)
  (path->string
   (build-path (info-dir) (extension-module-filename extension))))

(define (extensions-path)
  (build-path (info-dir) extensions-filename))

(define (instruction-extensions-path)
  (build-path (info-dir) instruction-extensions-filename))

(provide package-root
         extension-module-filename
         raw-instruction-path
         rebuilt-instruction-path
         instruction-info-path
         extensions-path
         instruction-extensions-path)
