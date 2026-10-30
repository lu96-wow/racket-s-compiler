#lang racket/base

;; ============================================================
;; Public instruction-path helper for the generated package.
;;
;; The actual layout lives in layout.rkt; this module keeps the
;; instruction-only API stable.
;; ============================================================

(require "layout.rkt")

(provide raw-instruction-path
         rebuilt-instruction-path)
