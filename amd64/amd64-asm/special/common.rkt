#lang racket
;;; amd64/amd64-asm/special/common.rkt
;;;
;;; Small helpers shared by handwritten special form families.

(require "../insn-core.rkt"
         "../encoding-plan.rkt"
         (only-in "../cc.rkt" cc-index))   ; 条件码编号的事实来源

(provide cc-index
         make-fixed-plan
         prefix-byte)

(define (make-fixed-plan name bytes)
  (lambda (operands)
    (unless (null? operands)
      (error name "~a takes no operands: ~e" name operands))
    (literal-plan bytes)))

(define (prefix-byte pname)
  (case pname
    [(lock) #xf0]
    [(rep repz) #xf3]
    [(repne repnz) #xf2]
    [else (error 'prefix-byte "unknown instruction prefix: ~e" pname)]))
