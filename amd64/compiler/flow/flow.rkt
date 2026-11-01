#lang racket
;;; compiler/flow/flow.rkt
;;;
;;; Compatibility entry for the core assembly pipeline.  Optional frontends
;;; (Loko, ELF image planning) live in their own flow modules and pass their
;;; stage tables to this generic engine.

(require "core.rkt")

(provide (all-from-out "core.rkt"))
