#lang racket/base

;; ============================================================
;; Source and output layout for the NASM-derived instruction table.
;;
;; There is exactly one build-time place that knows where the checked-in
;; NASM snapshot lives and where generated code is written.
;; ============================================================

(require racket/file
         racket/path
         racket/runtime-path)

(define-runtime-path self-path "paths.rkt")
(define binary-build-dir (path-only self-path))
(define project-root (simplify-path (build-path binary-build-dir "..")))

;; insns.pre.dat is produced by NASM's x86/preinsns.pl from x86/insns.dat.
;; Keeping the preprocessed snapshot in-tree makes the Racket build
;; independent of Perl while retaining the raw upstream source for audit.
(define default-source-path
  (build-path project-root "nasm" "insns.pre.dat"))
(define raw-source-path
  (build-path project-root "nasm" "insns.dat"))
(define default-output-dir
  (build-path project-root "generated"))

(define generated-gen-dir-parts '("gen"))
(define generated-insn-dir-parts '("gen" "insn"))
(define generated-table-filename "nasm.rkt")

(define (generated-gen-dir root)
  (apply build-path root generated-gen-dir-parts))

(define (generated-insn-dir root)
  (apply build-path root generated-insn-dir-parts))

(define (generated-table-path root)
  (build-path (generated-insn-dir root) generated-table-filename))

(provide project-root
         binary-build-dir
         default-source-path
         raw-source-path
         default-output-dir
         generated-gen-dir
         generated-insn-dir
         generated-table-path)
