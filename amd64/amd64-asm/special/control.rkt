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

(provide encode-jmp-short
         encode-jmp-near
         encode-jcc-short
         encode-jcc-near
         encode-call-near
         encode-indirect-transfer
         encode-setcc
         encode-cmovcc
         encode-ret
         encode-nop
         encode-ud2)

(define (encode-jmp-short operands)
  (match operands
    [(list off)
     (check-s8 off 'encode-jmp-short)
     (literal-plan (bytes* '(#xeb) (u8 off)))]
    [_ (error 'encode-jmp-short "jmp-short takes one offset: ~e" operands)]))

(define (encode-jmp-near operands)
  (match operands
    [(list off)
     (check-s32 off 'encode-jmp-near)
     (literal-plan (bytes* '(#xe9) (u32 off)))]
    [_ (error 'encode-jmp-near "jmp-near takes one offset: ~e" operands)]))

(define (encode-jcc-short operands)
  (match operands
    [(list cc off)
     (check-s8 off 'encode-jcc-short)
     (literal-plan (bytes* (u8 (+ #x70 (cc-index cc))) (u8 off)))]
    [_ (error 'encode-jcc-short "jcc-short takes cc and offset: ~e" operands)]))

(define (encode-jcc-near operands)
  (match operands
    [(list cc off)
     (check-s32 off 'encode-jcc-near)
     (literal-plan (bytes* '(#x0f) (u8 (+ #x80 (cc-index cc))) (u32 off)))]
    [_ (error 'encode-jcc-near "jcc-near takes cc and offset: ~e" operands)]))

(define (encode-call-near operands)
  (match operands
    [(list off)
     (check-s32 off 'encode-call-near)
     (literal-plan (bytes* '(#xe8) (u32 off)))]
    [_ (error 'encode-call-near "call-near takes one offset: ~e" operands)]))

(define (encode-indirect-transfer name opcode operands)
  (match operands
    [(list rm)
     (define rm* (parse-rm rm))
     (rm-plan 64 (regs-in-op rm*) (encode-rm rm* opcode) '(#xff))]
    [_ (error name "~a takes one operand: ~e" name operands)]))

(define (encode-setcc operands)
  (match operands
    [(list cc rm)
     (define rm* (parse-rm rm))
     (unless (= (rm-width rm*) 8)
       (error 'encode-setcc "setcc requires an 8-bit destination: ~e" rm))
     (rm-plan 8 (regs-in-op rm*)
              (encode-rm rm* 0)
              (list #x0f (+ #x90 (cc-index cc))))]
    [_ (error 'encode-setcc "setcc takes a condition and an operand: ~e" operands)]))

(define (encode-cmovcc operands)
  (match operands
    [(list cc dst src)
     (define dst* (parse-reg dst))
     (define src* (parse-rm src))
     (define width (reg-width dst*))
     (unless (memq width '(16 32 64))
       (error 'encode-cmovcc "cmovcc requires a 16/32/64-bit destination: ~e" dst))
     (unless (= width (rm-width src*))
       (error 'encode-cmovcc "operand widths do not match: ~e ~e" dst src))
     (rm-plan width (list dst*) (encode-rm src* dst*)
              (list #x0f (+ #x40 (cc-index cc))))]
    [_ (error 'encode-cmovcc "cmovcc takes cc, dst, src: ~e" operands)]))

(define (encode-ret operands)
  (unless (null? operands) (error 'encode-ret "ret takes no operands: ~e" operands))
  (literal-plan '(#xc3)))

(define (encode-nop operands)
  (unless (null? operands) (error 'encode-nop "nop takes no operands: ~e" operands))
  (literal-plan '(#x90)))

(define (encode-ud2 operands)
  (unless (null? operands) (error 'encode-ud2 "ud2 takes no operands: ~e" operands))
  (literal-plan '(#x0f #x0b)))
