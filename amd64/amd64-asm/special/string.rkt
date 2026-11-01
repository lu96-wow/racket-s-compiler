#lang racket
;;; amd64/amd64-asm/special/string.rkt
;;;
;;; Implicit-operand string instructions.

(require "../sexp.rkt"
         "../encoding-plan.rkt"
         "../registers.rkt"
         "../insn-core.rkt"
         "../operand.rkt")

(provide encode-movs
         encode-stos
         encode-ins
         encode-outs)

(define (string-memory-width op who)
  (define m (parse-rm op))
  (unless (mem? m) (error who "string instruction needs a memory operand: ~e" op))
  (mem-width m))

(define (encode-movs operands)
  (match operands
    [(list dst src)
     (define w (string-memory-width dst 'encode-movs))
     (unless (= w (string-memory-width src 'encode-movs))
       (error 'encode-movs "operand widths do not match: ~e ~e" dst src))
     (case w
       [(8) (literal-plan '(#xa4))]
       [(16) (literal-plan '(#x66 #xa5))]
       [(32) (literal-plan '(#xa5))]
       [(64) (literal-plan '(#x48 #xa5))]
       [else (error 'encode-movs "unsupported movs width: ~e" w)])]
    [_ (error 'encode-movs "movs takes dst, src: ~e" operands)]))

(define (encode-stos operands)
  (match operands
    [(list dst src)
     (define w (string-memory-width dst 'encode-stos))
     (define s (parse-reg src))
     (unless (= w (reg-width s))
       (error 'encode-stos "operand widths do not match: ~e ~e" dst src))
     (case w
       [(8) (literal-plan '(#xaa))]
       [(16) (literal-plan '(#x66 #xab))]
       [(32) (literal-plan '(#xab))]
       [(64) (literal-plan '(#x48 #xab))]
       [else (error 'encode-stos "unsupported stos width: ~e" w)])]
    [_ (error 'encode-stos "stos takes dst, src: ~e" operands)]))

(define (string-port? x)
  (and (symbol? x) (eq? x 'dx)))

(define (encode-ins operands)
  (match operands
    [(list dst port)
     (unless (string-port? port)
       (error 'encode-ins "ins port must be dx: ~e" port))
     (define w (string-memory-width dst 'encode-ins))
     (case w
       [(8) (literal-plan '(#x6c))]
       [(16) (literal-plan '(#x66 #x6d))]
       [(32) (literal-plan '(#x6d))]
       [else (error 'encode-ins "ins supports only b8/b16/b32: ~e" w)])]
    [_ (error 'encode-ins "ins takes dst, dx: ~e" operands)]))

(define (encode-outs operands)
  (match operands
    [(list port src)
     (unless (string-port? port)
       (error 'encode-outs "outs port must be dx: ~e" port))
     (define w (string-memory-width src 'encode-outs))
     (case w
       [(8) (literal-plan '(#x6e))]
       [(16) (literal-plan '(#x66 #x6f))]
       [(32) (literal-plan '(#x6f))]
       [else (error 'encode-outs "outs supports only b8/b16/b32: ~e" w)])]
    [_ (error 'encode-outs "outs takes dx, src: ~e" operands)]))
