#lang racket
;;; amd64/amd64-asm/insn.rkt
;;;
;;; Stable facade for the amd64 instruction encoder.  The actual work lives in:
;;;   operand.rkt   operand parsing/helpers
;;;   special.rkt   handwritten form families -> bytes
;;;   insn-generic.rkt generated NASM table -> constraint/selection plan
;;;   plan.rkt      resolved-plan + size/encode facade
;;;
;;; Callers should prefer instruction-plan/plan-size when they are layout-like,
;;; and encode-instruction when they need the final bytes.

(require "plan.rkt")

(provide encode-instruction
         instruction-size
         instruction-arity
         known-instruction?
         instruction-plan
         plan-size
         encode-plan
         resolved-plan?
         immediate-form
         symbolic-immediate?
         choose-symbolic-immediate-forms)
