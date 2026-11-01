#lang racket
;;; amd64/amd64-asm/special/system.rkt
;;;
;;; PC descriptor-table and system-register special forms.

(require "../sexp.rkt"
         "../registers.rkt"
         "../insn-core.rkt"
         "../operand.rkt")

(provide encode-descriptor-table
         encode-system-rm16)

(define (encode-descriptor-table name opcode digit operands)
  (match operands
    [(list m)
     (define m* (parse-rm m))
     (unless (mem? m*)
       (error name "~a needs a memory operand: ~e" name m))
     (emit-rm-with-prefixes 32 (regs-in-op m*) (encode-rm m* digit)
                   (list #x0f opcode) '() '())]
    [_ (error name "~a takes one memory operand: ~e" name operands)]))

(define (encode-system-rm16 name digit operands)
  (match operands
    [(list rm)
     (define r (parse-rm rm))
     (define width (if (mem? r) (mem-width r) (reg-width r)))
     (unless (= width 16)
       (error name "~a needs a 16-bit operand: ~e" name rm))
     (emit-rm-with-prefixes 32 (regs-in-op r) (encode-rm r digit)
                   '(#x0f #x00) '() '())]
    [_ (error name "~a takes one operand: ~e" name operands)]))
