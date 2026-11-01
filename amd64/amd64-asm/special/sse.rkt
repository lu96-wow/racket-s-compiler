#lang racket
;;; amd64/amd64-asm/special/sse.rkt
;;;
;;; Legacy SSE/XMM special forms.

(require "../sexp.rkt"
         "../encoding-plan.rkt"
         "../registers.rkt"
         "../insn-core.rkt"
         "../operand.rkt")

(provide plan-movss
         plan-movd
         plan-movq
         plan-movdqa
         plan-sse-scalar
         plan-roundss
         plan-cvtsi2ss
         plan-mxcsr
         plan-fpstate)

(define (xmm-operand? x)
  (define r (cond
              [(reg? x) x]
              [(symbol? x) (lookup-register x #f)]
              [else #f]))
  (and r (xmm-register? r)))

(define (gpr-operand? x)
  (define r (cond
              [(reg? x) x]
              [(symbol? x) (lookup-register x #f)]
              [else #f]))
  (and r (gpr-register? r)))

(define (check-mem-width op width who)
  (when (and (mem? op) (not (= (mem-width op) width)))
    (error who "memory width must be b~a: ~e" width op)))

(define (sse-rm-plan prefix width regs rm-enc opcode [imm '()])
  (rm-plan width regs rm-enc opcode imm prefix))

(define (plan-movss operands)
  (match operands
    [(list dst src)
     (cond
       [(xmm-operand? dst)
        (define d (parse-xmm dst))
        (define s (parse-xmm-or-mem src))
        (check-mem-width s 32 'plan-movss)
        (sse-rm-plan (list #xf3) 32 (list d) (make-rm-encoding s d) '(#x0f #x10))]
       [(or (mem? dst) (mem-form? dst))
        (define d (parse-rm dst))
        (define s (parse-xmm src))
        (check-mem-width d 32 'plan-movss)
        (sse-rm-plan (list #xf3) 32 (list s) (make-rm-encoding d s) '(#x0f #x11))]
       [else (error 'plan-movss "unsupported movss operands: ~e" operands)])]
    [_ (error 'plan-movss "movss takes two operands: ~e" operands)]))

(define (plan-movd operands)
  (match operands
    [(list dst src)
     (cond
       [(xmm-operand? dst)
        (define d (parse-xmm dst))
        (define s (parse-rm src))
        (check-mem-width s 32 'plan-movd)
        (unless (= 32 (if (mem? s) (mem-width s) (reg-width s)))
          (error 'plan-movd "movd source must be 32 bits: ~e" src))
        (sse-rm-plan (list #x66) 32 (list d) (make-rm-encoding s d) '(#x0f #x6e))]
       [(or (mem? dst) (mem-form? dst) (gpr-operand? dst))
        (define d (parse-rm dst))
        (define s (parse-xmm src))
        (check-mem-width d 32 'plan-movd)
        (unless (= 32 (if (mem? d) (mem-width d) (reg-width d)))
          (error 'plan-movd "movd destination must be 32 bits: ~e" dst))
        (sse-rm-plan (list #x66) 32 (list s) (make-rm-encoding d s) '(#x0f #x7e))]
       [else (error 'plan-movd "unsupported movd operands: ~e" operands)])]
    [_ (error 'plan-movd "movd takes two operands: ~e" operands)]))

(define (plan-movq operands)
  (match operands
    [(list dst src)
     (cond
       [(xmm-operand? dst)
        (define d (parse-xmm dst))
        (cond
          [(or (xmm-operand? src) (mem? src) (mem-form? src))
           (define s (parse-xmm-or-mem src))
           (check-mem-width s 64 'plan-movq)
           (sse-rm-plan (list #xf3) 32 (list d) (make-rm-encoding s d) '(#x0f #x7e))]
          [(gpr-operand? src)
           (define s (parse-reg src))
           (unless (= 64 (reg-width s))
             (error 'plan-movq "movq GPR source must be 64 bits: ~e" src))
           (sse-rm-plan (list #x66) 64 (list d) (make-rm-encoding s d) '(#x0f #x6e))]
          [else (error 'plan-movq "unsupported movq source: ~e" src)])]
       [(or (mem? dst) (mem-form? dst))
        (define d (parse-rm dst))
        (define s (parse-xmm src))
        (check-mem-width d 64 'plan-movq)
        (sse-rm-plan (list #x66) 32 (list s) (make-rm-encoding d s) '(#x0f #xd6))]
       [(gpr-operand? dst)
        (define d (parse-reg dst))
        (unless (= 64 (reg-width d))
          (error 'plan-movq "movq GPR destination must be 64 bits: ~e" dst))
        (define s (parse-xmm src))
        (sse-rm-plan (list #x66) 64 (list s) (make-rm-encoding d s) '(#x0f #x7e))]
       [else (error 'plan-movq "unsupported movq operands: ~e" operands)])]
    [_ (error 'plan-movq "movq takes two operands: ~e" operands)]))

(define (plan-movdqa operands)
  (match operands
    [(list dst src)
     (cond
       [(xmm-operand? dst)
        (define d (parse-xmm dst))
        (define s (parse-xmm-or-mem src))
        (check-mem-width s 128 'plan-movdqa)
        (sse-rm-plan (list #x66) 32 (list d) (make-rm-encoding s d) '(#x0f #x6f))]
       [(or (mem? dst) (mem-form? dst))
        (define d (parse-rm dst))
        (define s (parse-xmm src))
        (check-mem-width d 128 'plan-movdqa)
        (sse-rm-plan (list #x66) 32 (list s) (make-rm-encoding d s) '(#x0f #x7f))]
       [else (error 'plan-movdqa "unsupported movdqa operands: ~e" operands)])]
    [_ (error 'plan-movdqa "movdqa takes two operands: ~e" operands)]))

(define (plan-sse-scalar name opcode prefix mem-width operands)
  (match operands
    [(list dst src)
     (define d (parse-xmm dst))
     (define s (parse-xmm-or-mem src))
     (check-mem-width s mem-width name)
     (sse-rm-plan prefix 32 (list d) (make-rm-encoding s d) (list #x0f opcode))]
    [_ (error name "~a takes two operands: ~e" name operands)]))

(define (plan-roundss operands)
  (match operands
    [(list dst src imm)
     (define d (parse-xmm dst))
     (define s (parse-xmm-or-mem src))
     (check-mem-width s 32 'plan-roundss)
     (define v (or (immediate-value imm)
                   (error 'plan-roundss "roundss immediate must be an integer: ~e" imm)))
     (check-imm8 v 'plan-roundss)
     (sse-rm-plan (list #x66) 32 (list d) (make-rm-encoding s d) '(#x0f #x3a #x0a) (u8 v))]
    [_ (error 'plan-roundss "roundss takes dst, src, imm8: ~e" operands)]))

(define (plan-cvtsi2ss operands)
  (match operands
    [(list dst src)
     (define d (parse-xmm dst))
     (define s (parse-rm src))
     (define width (if (mem? s) (mem-width s) (reg-width s)))
     (unless (memq width '(32 64))
       (error 'plan-cvtsi2ss "source must be 32/64 bits: ~e" src))
     (sse-rm-plan (list #xf3) (if (= width 64) 64 32)
               (list d) (make-rm-encoding s d) '(#x0f #x2a))]
    [_ (error 'plan-cvtsi2ss "cvtsi2ss takes dst, src: ~e" operands)]))

;;; FXSAVE / FXRSTOR: 0F AE /0 和 /1，操作数是 512 字节的保存区。
;;; 和 ldmxcsr/stmxcsr 一样只收内存操作数；这里**不检查**操作数宽度 ——
;;; 那条指令的"宽度"是 512 字节，和 mem 宽度的标注无关，编码只需要地址。
(define (plan-fpstate name digit operands)
  (match operands
    [(list m)
     (define m* (parse-rm m))
     (unless (mem? m*) (error name "~a needs a memory operand: ~e" name m))
     (sse-rm-plan '() 32 (regs-in-op m*) (make-rm-encoding m* digit) '(#x0f #xae))]
    [_ (error name "~a takes one memory operand: ~e" name operands)]))

(define (plan-mxcsr name digit operands)
  (match operands
    [(list m)
     (define m* (parse-rm m))
     (unless (mem? m*) (error name "~a needs a memory operand: ~e" name m))
     (check-mem-width m* 32 name)
     (sse-rm-plan '() 32 (regs-in-op m*) (make-rm-encoding m* digit) '(#x0f #xae))]
    [_ (error name "~a takes one memory operand: ~e" name operands)]))
