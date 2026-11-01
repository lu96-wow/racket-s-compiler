#lang racket
;;; amd64/amd64-asm/special.rkt
;;;
;;; Facade for handwritten special form families.  The implementation lives in
;;; special/*.rkt; this module keeps the stable internal API for plan.rkt.

(require "special/common.rkt"
         "special/table.rkt")

(provide special-known?
         special-arity
         special-encode
         prefix-byte)
