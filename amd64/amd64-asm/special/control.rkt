#lang racket
;;; amd64/amd64-asm/special/control.rkt
;;;
;;; Explicit control-transfer forms and condition-code pseudo forms.

(require "../sexp.rkt"
         "../encoding-plan.rkt"
         "../registers.rkt"
         "../insn-core.rkt"
         "../operand.rkt"
         "common.rkt")

(provide plan-jmp-short
         plan-jmp-near
         plan-jcc-short
         plan-jcc-near
         plan-call-near
         plan-indirect-transfer
         plan-setcc
         plan-cmovcc
         plan-ret
         plan-nop
         plan-ud2)

(define (plan-jmp-short operands)
  (match operands
    [(list off)
     (check-s8 off 'plan-jmp-short)
     (literal-plan (bytes* '(#xeb) (u8 off)))]
    [_ (error 'plan-jmp-short "jmp-short takes one offset: ~e" operands)]))

(define (plan-jmp-near operands)
  (match operands
    [(list off)
     (check-s32 off 'plan-jmp-near)
     (literal-plan (bytes* '(#xe9) (u32 off)))]
    [_ (error 'plan-jmp-near "jmp-near takes one offset: ~e" operands)]))

(define (plan-jcc-short operands)
  (match operands
    [(list cc off)
     (check-s8 off 'plan-jcc-short)
     (literal-plan (bytes* (u8 (+ #x70 (cc-index cc))) (u8 off)))]
    [_ (error 'plan-jcc-short "jcc-short takes cc and offset: ~e" operands)]))

(define (plan-jcc-near operands)
  (match operands
    [(list cc off)
     (check-s32 off 'plan-jcc-near)
     (literal-plan (bytes* '(#x0f) (u8 (+ #x80 (cc-index cc))) (u32 off)))]
    [_ (error 'plan-jcc-near "jcc-near takes cc and offset: ~e" operands)]))

(define (plan-call-near operands)
  (match operands
    [(list off)
     (check-s32 off 'plan-call-near)
     (literal-plan (bytes* '(#xe8) (u32 off)))]
    [_ (error 'plan-call-near "call-near takes one offset: ~e" operands)]))

(define (plan-indirect-transfer name opcode operands)
  (match operands
    [(list rm)
     (define rm* (parse-rm rm))
     (rm-plan 64 (regs-in-op rm*) (make-rm-encoding rm* opcode) '(#xff))]
    [_ (error name "~a takes one operand: ~e" name operands)]))

(define (plan-setcc operands)
  (match operands
    [(list cc rm)
     (define rm* (parse-rm rm))
     (unless (= (rm-width rm*) 8)
       (error 'plan-setcc "setcc requires an 8-bit destination: ~e" rm))
     (rm-plan 8 (regs-in-op rm*)
              (make-rm-encoding rm* 0)
              (list #x0f (+ #x90 (cc-index cc))))]
    [_ (error 'plan-setcc "setcc takes a condition and an operand: ~e" operands)]))

(define (plan-cmovcc operands)
  (match operands
    [(list cc dst src)
     (define dst* (parse-reg dst))
     (define src* (parse-rm src))
     (define width (reg-width dst*))
     (unless (memq width '(16 32 64))
       (error 'plan-cmovcc "cmovcc requires a 16/32/64-bit destination: ~e" dst))
     (unless (= width (rm-width src*))
       (error 'plan-cmovcc "operand widths do not match: ~e ~e" dst src))
     (rm-plan width (list dst*) (make-rm-encoding src* dst*)
              (list #x0f (+ #x40 (cc-index cc))))]
    [_ (error 'plan-cmovcc "cmovcc takes cc, dst, src: ~e" operands)]))

(define (plan-ret operands)
  (unless (null? operands) (error 'plan-ret "ret takes no operands: ~e" operands))
  (literal-plan '(#xc3)))

(define (plan-nop operands)
  (unless (null? operands) (error 'plan-nop "nop takes no operands: ~e" operands))
  (literal-plan '(#x90)))

(define (plan-ud2 operands)
  (unless (null? operands) (error 'plan-ud2 "ud2 takes no operands: ~e" operands))
  (literal-plan '(#x0f #x0b)))
