#lang racket/base

;; ============================================================
;; Generated-package layout contract
;;
;; Pure relative path segments and file names. Both sides use this file:
;;   - binary-build/paths.rkt      (build-time absolute output paths)
;;   - runtime/lib/layout.rkt      (runtime package-relative paths)
;;
;; Keep this module free of runtime-path/absolute-path logic.
;; ============================================================

(define lib-dir-parts
  '("lib"))

(define gen-dir-parts
  '("gen"))

(define raw-field-dir-parts
  '("lib" "riscv" "raw"))

(define rebuilt-field-dir-parts
  '("gen" "riscv" "field" "rebuilt"))

(define raw-instruction-dir-parts
  '("gen" "riscv" "instruction" "raw"))

(define rebuilt-instruction-dir-parts
  '("gen" "riscv" "instruction" "rebuilt"))

(define info-dir-parts
  '("gen" "riscv" "info"))

(define info-lib-dir-parts
  '("lib" "info"))

(define base-filename "base.rkt")
(define extensions-filename "extensions.rkt")
(define instruction-extensions-filename "instruction_extensions.rkt")

(define (extension-module-filename extension)
  (unless (symbol? extension)
    (raise-argument-error 'extension-module-filename "symbol?" extension))
  (string-append (symbol->string extension) ".rkt"))

;; Each generated <extension>.rkt exports this variable.
(define (extension-info-variable extension)
  (unless (symbol? extension)
    (raise-argument-error 'extension-info-variable "symbol?" extension))
  (string->symbol (format "~a-instructions" extension)))

(provide lib-dir-parts
         gen-dir-parts
         raw-field-dir-parts
         rebuilt-field-dir-parts
         raw-instruction-dir-parts
         rebuilt-instruction-dir-parts
         info-dir-parts
         info-lib-dir-parts
         base-filename
         extensions-filename
         instruction-extensions-filename
         extension-module-filename
         extension-info-variable)
