#lang racket
;;; amd64/amd64-asm/special/system.rkt
;;;
;;; PC descriptor-table and system-register special forms.

(require "../sexp.rkt"
         "../encoding-plan.rkt"
         "../registers.rkt"
         "../insn-core.rkt"
         "../operand.rkt")

(provide plan-descriptor-table
         plan-system-rm16)

(define (plan-descriptor-table name opcode digit operands)
  (match operands
    [(list m)
     (define m* (parse-rm m))
     (unless (mem? m*)
       (error name "~a needs a memory operand: ~e" name m))
     (rm-plan 32 (regs-in-op m*) (make-rm-encoding m* digit)
              (list #x0f opcode))]
    [_ (error name "~a takes one memory operand: ~e" name operands)]))

(define (plan-system-rm16 name digit operands)
  (match operands
    [(list rm)
     (define r (parse-rm rm))
     (define width (if (mem? r) (mem-width r) (reg-width r)))
     (unless (= width 16)
       (error name "~a needs a 16-bit operand: ~e" name rm))
     (rm-plan 32 (regs-in-op r) (make-rm-encoding r digit)
              '(#x0f #x00))]
    [_ (error name "~a takes one operand: ~e" name operands)]))
