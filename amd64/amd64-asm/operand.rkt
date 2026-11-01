#lang racket
;;; amd64/amd64-asm/operand.rkt
;;;
;;; Shared operand parsing/normalization used by handwritten special encoders
;;; and by the plan facade.  This module does not choose instruction forms and
;;; does not emit bytes.

(require "shape.rkt"
         "memory.rkt"
         "registers.rkt")

(provide rm-width
         rm-operand?
         parse-rm
         parse-reg
         parse-xmm
         parse-xmm-or-mem
         immediate-value
         immediate-form
         symbolic-immediate?
         choose-symbolic-immediate-forms)

(define (rm-width op)
  (cond
    [(reg? op) (reg-width op)]
    [(mem? op) (mem-width op)]
    [else (error 'rm-width "expected register or memory operand: ~e" op)]))

(define (rm-operand? op)
  (or (symbol? op) (reg? op) (mem-form? op) (mem? op)))

(define (parse-rm op)
  (cond
    [(mem? op) op]
    [(mem-form? op) (parse-mem op)]
    [(or (reg? op) (symbol? op))
     (define r (if (reg? op) op (lookup-register op)))
     (unless (gpr-register? r)
       (error 'parse-rm "expected GPR or memory, got XMM register: ~e" op))
     r]
    [else (error 'parse-rm "expected register or memory operand: ~e" op)]))

(define (parse-reg op)
  (define r (cond
              [(reg? op) op]
              [(symbol? op) (lookup-register op #f)]
              [else #f]))
  (cond
    [(and r (gpr-register? r)) r]
    [(and r (xmm-register? r))
     (error 'parse-reg "expected GPR, got XMM register: ~e" op)]
    [else (error 'parse-reg "expected register operand: ~e" op)]))

(define (parse-xmm op)
  (define r (cond
              [(reg? op) op]
              [(symbol? op) (lookup-register op #f)]
              [else #f]))
  (cond
    [(and r (xmm-register? r)) r]
    [(and r (gpr-register? r))
     (error 'parse-xmm "expected XMM register, got GPR: ~e" op)]
    [else (error 'parse-xmm "expected XMM register: ~e" op)]))

(define (parse-xmm-or-mem op)
  (cond
    [(mem? op) op]
    [(mem-form? op) (parse-mem op)]
    [(or (reg? op) (symbol? op)) (parse-xmm op)]
    [else (error 'parse-xmm-or-mem "expected XMM register or memory: ~e" op)]))

(define (immediate-value op)
  (cond
    [(exact-integer? op) op]
    [(and (form? op) (memq (car op) '(imm8 imm16 imm32 imm64)) (= 2 (length op)))
     (cadr op)]
    [else #f]))

(define (immediate-form op)
  (and (form? op) (memq (car op) '(imm8 imm16 imm32 imm64)) (= 2 (length op))
       (car op)))

(define (symbolic-immediate? op)
  (and (address-expr? op) (not (exact-integer? op))))

;; Choose one fixed immediate width for each unresolved address expression.
;; Layout and encode must agree on the form, so the choice is made once, here,
;; from the instruction and its operands -- never from the final value.
(define (choose-symbolic-immediate-forms name operands)
  (define (wrap op)
    (if (symbolic-immediate? op) (list 'imm32 op) op))
  (cond
    [(eq? name 'prefix)
     (match operands
       [(list pname inner)
        (and (form? inner)
             (list pname (cons (car inner)
                               (choose-symbolic-immediate-forms (car inner) (cdr inner)))))]
       [_ operands])]
    [(memq name '(jmp-short jmp-near jcc-short jcc-near call-near))
     operands]
    [(eq? name 'mov)
     (match operands
       [(list dst src)
        (cond
          [(symbolic-immediate? src)
           (define dst* (and (rm-operand? dst) (parse-rm dst)))
           (list dst (if (and (reg? dst*) (= 64 (reg-width dst*)))
                         (list 'imm64 src)
                         (list 'imm32 src)))]
          [else operands])]
       [_ operands])]
    [else (map wrap operands)]))

