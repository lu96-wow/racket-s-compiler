#lang racket
;;; amd64/amd64-asm/special/string.rkt
;;;
;;; Implicit-operand string instructions.

(require "../sexp.rkt"
         "../encoding-plan.rkt"
         "../registers.rkt"
         "../insn-core.rkt"
         "../operand.rkt")

(provide plan-movs
         plan-stos
         plan-ins
         plan-outs)

(define (string-memory-width op who)
  (define m (parse-rm op))
  (unless (mem? m) (error who "string instruction needs a memory operand: ~e" op))
  (mem-width m))

(define (plan-movs operands)
  (match operands
    [(list dst src)
     (define w (string-memory-width dst 'plan-movs))
     (unless (= w (string-memory-width src 'plan-movs))
       (error 'plan-movs "operand widths do not match: ~e ~e" dst src))
     (case w
       [(8) (literal-plan '(#xa4))]
       [(16) (literal-plan '(#x66 #xa5))]
       [(32) (literal-plan '(#xa5))]
       [(64) (literal-plan '(#x48 #xa5))]
       [else (error 'plan-movs "unsupported movs width: ~e" w)])]
    [_ (error 'plan-movs "movs takes dst, src: ~e" operands)]))

(define (plan-stos operands)
  (match operands
    [(list dst src)
     (define w (string-memory-width dst 'plan-stos))
     (define s (parse-reg src))
     (unless (= w (reg-width s))
       (error 'plan-stos "operand widths do not match: ~e ~e" dst src))
     (case w
       [(8) (literal-plan '(#xaa))]
       [(16) (literal-plan '(#x66 #xab))]
       [(32) (literal-plan '(#xab))]
       [(64) (literal-plan '(#x48 #xab))]
       [else (error 'plan-stos "unsupported stos width: ~e" w)])]
    [_ (error 'plan-stos "stos takes dst, src: ~e" operands)]))

(define (string-port? x)
  (and (symbol? x) (eq? x 'dx)))

(define (plan-ins operands)
  (match operands
    [(list dst port)
     (unless (string-port? port)
       (error 'plan-ins "ins port must be dx: ~e" port))
     (define w (string-memory-width dst 'plan-ins))
     (case w
       [(8) (literal-plan '(#x6c))]
       [(16) (literal-plan '(#x66 #x6d))]
       [(32) (literal-plan '(#x6d))]
       [else (error 'plan-ins "ins supports only b8/b16/b32: ~e" w)])]
    [_ (error 'plan-ins "ins takes dst, dx: ~e" operands)]))

(define (plan-outs operands)
  (match operands
    [(list port src)
     (unless (string-port? port)
       (error 'plan-outs "outs port must be dx: ~e" port))
     (define w (string-memory-width src 'plan-outs))
     (case w
       [(8) (literal-plan '(#x6e))]
       [(16) (literal-plan '(#x66 #x6f))]
       [(32) (literal-plan '(#x6f))]
       [else (error 'plan-outs "outs supports only b8/b16/b32: ~e" w)])]
    [_ (error 'plan-outs "outs takes dx, src: ~e" operands)]))
