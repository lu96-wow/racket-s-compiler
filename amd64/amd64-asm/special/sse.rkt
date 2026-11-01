#lang racket
;;; amd64/amd64-asm/special/sse.rkt
;;;
;;; Legacy SSE/XMM special forms.

(require "../sexp.rkt"
         "../registers.rkt"
         "../insn-core.rkt"
         "../operand.rkt")

(provide encode-movss
         encode-movd
         encode-movq
         encode-movdqa
         encode-sse-scalar
         encode-roundss
         encode-cvtsi2ss
         encode-mxcsr)

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

(define (emit-sse prefix width regs rm-enc opcode [imm '()])
  (emit-rm-with-prefixes width regs rm-enc opcode imm prefix))

(define (encode-movss operands)
  (match operands
    [(list dst src)
     (cond
       [(xmm-operand? dst)
        (define d (parse-xmm dst))
        (define s (parse-xmm-or-mem src))
        (check-mem-width s 32 'encode-movss)
        (emit-sse (list #xf3) 32 (list d) (encode-rm s d) '(#x0f #x10))]
       [(or (mem? dst) (mem-form? dst))
        (define d (parse-rm dst))
        (define s (parse-xmm src))
        (check-mem-width d 32 'encode-movss)
        (emit-sse (list #xf3) 32 (list s) (encode-rm d s) '(#x0f #x11))]
       [else (error 'encode-movss "unsupported movss operands: ~e" operands)])]
    [_ (error 'encode-movss "movss takes two operands: ~e" operands)]))

(define (encode-movd operands)
  (match operands
    [(list dst src)
     (cond
       [(xmm-operand? dst)
        (define d (parse-xmm dst))
        (define s (parse-rm src))
        (check-mem-width s 32 'encode-movd)
        (unless (= 32 (if (mem? s) (mem-width s) (reg-width s)))
          (error 'encode-movd "movd source must be 32 bits: ~e" src))
        (emit-sse (list #x66) 32 (list d) (encode-rm s d) '(#x0f #x6e))]
       [(or (mem? dst) (mem-form? dst) (gpr-operand? dst))
        (define d (parse-rm dst))
        (define s (parse-xmm src))
        (check-mem-width d 32 'encode-movd)
        (unless (= 32 (if (mem? d) (mem-width d) (reg-width d)))
          (error 'encode-movd "movd destination must be 32 bits: ~e" dst))
        (emit-sse (list #x66) 32 (list s) (encode-rm d s) '(#x0f #x7e))]
       [else (error 'encode-movd "unsupported movd operands: ~e" operands)])]
    [_ (error 'encode-movd "movd takes two operands: ~e" operands)]))

(define (encode-movq operands)
  (match operands
    [(list dst src)
     (cond
       [(xmm-operand? dst)
        (define d (parse-xmm dst))
        (cond
          [(or (xmm-operand? src) (mem? src) (mem-form? src))
           (define s (parse-xmm-or-mem src))
           (check-mem-width s 64 'encode-movq)
           (emit-sse (list #xf3) 32 (list d) (encode-rm s d) '(#x0f #x7e))]
          [(gpr-operand? src)
           (define s (parse-reg src))
           (unless (= 64 (reg-width s))
             (error 'encode-movq "movq GPR source must be 64 bits: ~e" src))
           (emit-sse (list #x66) 64 (list d) (encode-rm s d) '(#x0f #x6e))]
          [else (error 'encode-movq "unsupported movq source: ~e" src)])]
       [(or (mem? dst) (mem-form? dst))
        (define d (parse-rm dst))
        (define s (parse-xmm src))
        (check-mem-width d 64 'encode-movq)
        (emit-sse (list #x66) 32 (list s) (encode-rm d s) '(#x0f #xd6))]
       [(gpr-operand? dst)
        (define d (parse-reg dst))
        (unless (= 64 (reg-width d))
          (error 'encode-movq "movq GPR destination must be 64 bits: ~e" dst))
        (define s (parse-xmm src))
        (emit-sse (list #x66) 64 (list s) (encode-rm d s) '(#x0f #x7e))]
       [else (error 'encode-movq "unsupported movq operands: ~e" operands)])]
    [_ (error 'encode-movq "movq takes two operands: ~e" operands)]))

(define (encode-movdqa operands)
  (match operands
    [(list dst src)
     (cond
       [(xmm-operand? dst)
        (define d (parse-xmm dst))
        (define s (parse-xmm-or-mem src))
        (check-mem-width s 128 'encode-movdqa)
        (emit-sse (list #x66) 32 (list d) (encode-rm s d) '(#x0f #x6f))]
       [(or (mem? dst) (mem-form? dst))
        (define d (parse-rm dst))
        (define s (parse-xmm src))
        (check-mem-width d 128 'encode-movdqa)
        (emit-sse (list #x66) 32 (list s) (encode-rm d s) '(#x0f #x7f))]
       [else (error 'encode-movdqa "unsupported movdqa operands: ~e" operands)])]
    [_ (error 'encode-movdqa "movdqa takes two operands: ~e" operands)]))

(define (encode-sse-scalar name opcode prefix mem-width operands)
  (match operands
    [(list dst src)
     (define d (parse-xmm dst))
     (define s (parse-xmm-or-mem src))
     (check-mem-width s mem-width name)
     (emit-sse prefix 32 (list d) (encode-rm s d) (list #x0f opcode))]
    [_ (error name "~a takes two operands: ~e" name operands)]))

(define (encode-roundss operands)
  (match operands
    [(list dst src imm)
     (define d (parse-xmm dst))
     (define s (parse-xmm-or-mem src))
     (check-mem-width s 32 'encode-roundss)
     (define v (or (immediate-value imm)
                   (error 'encode-roundss "roundss immediate must be an integer: ~e" imm)))
     (check-imm8 v 'encode-roundss)
     (emit-sse (list #x66) 32 (list d) (encode-rm s d) '(#x0f #x3a #x0a) (u8 v))]
    [_ (error 'encode-roundss "roundss takes dst, src, imm8: ~e" operands)]))

(define (encode-cvtsi2ss operands)
  (match operands
    [(list dst src)
     (define d (parse-xmm dst))
     (define s (parse-rm src))
     (define width (if (mem? s) (mem-width s) (reg-width s)))
     (unless (memq width '(32 64))
       (error 'encode-cvtsi2ss "source must be 32/64 bits: ~e" src))
     (emit-sse (list #xf3) (if (= width 64) 64 32)
               (list d) (encode-rm s d) '(#x0f #x2a))]
    [_ (error 'encode-cvtsi2ss "cvtsi2ss takes dst, src: ~e" operands)]))

(define (encode-mxcsr name digit operands)
  (match operands
    [(list m)
     (define m* (parse-rm m))
     (unless (mem? m*) (error name "~a needs a memory operand: ~e" name m))
     (check-mem-width m* 32 name)
     (emit-sse '() 32 (regs-in-op m*) (encode-rm m* digit) '(#x0f #xae))]
    [_ (error name "~a takes one memory operand: ~e" name operands)]))
