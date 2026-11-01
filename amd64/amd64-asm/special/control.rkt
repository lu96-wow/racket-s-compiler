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
         plan-jmp-far
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

;; 远跳: (far 选择子 偏移) -> EA + 偏移(32) + 选择子(16)。
;; 偏移是**绝对**地址表达式（不是相对位移），所以这里不做 relax，只是等
;; encode 把符号解析成整数。尺寸固定 7 字节：多引导头的 32 位引导代码用它
;; 切到长模式选择子，之后才是 64 位代码。
(define (plan-jmp-far operands)
  (match operands
    [(list sel off)
     (unless (and (exact-integer? sel) (<= 0 sel #xffff))
       (error 'plan-jmp-far "far pointer selector must be 0..65535: ~e" sel))
     (define value (if (immediate-form off) (immediate-value off) off))
     (unless (exact-integer? value)
       (error 'plan-jmp-far "far pointer offset must be resolved to an integer: ~e" off))
     (check-imm32 value 'plan-jmp-far)
     (literal-plan (bytes* '(#xea) (u32 value) (u16 sel)))]
    [_ (error 'plan-jmp-far "jmp-far takes a selector and an offset: ~e" operands)]))

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
