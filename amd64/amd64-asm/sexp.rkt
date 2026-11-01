#lang racket
;;; amd64/amd64-asm/sexp.rkt
;;;
;;; Compatibility facade for the generic s-expression shape and the amd64
;;; memory operand shape.  New code may require shape.rkt / memory.rkt directly.

(require "shape.rkt"
         "memory.rkt")

(provide (all-from-out "shape.rkt")
         (all-from-out "memory.rkt"))
