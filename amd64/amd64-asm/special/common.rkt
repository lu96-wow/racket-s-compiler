#lang racket
;;; amd64/amd64-asm/special/common.rkt
;;;
;;; Small helpers shared by handwritten special form families.

(require "../insn-core.rkt"
         "../encoding-plan.rkt")

(provide cc-index
         make-fixed-plan
         prefix-byte)

(define (cc-index cc)
  (case cc
    [(o) 0] [(no) 1]
    [(b) 2] [(ae) 3]
    [(e) 4] [(ne) 5]
    [(be) 6] [(a) 7]
    [(s) 8] [(ns) 9]
    [(p) 10] [(np) 11]
    [(l) 12] [(ge) 13]
    [(le) 14] [(g) 15]
    [else (error 'cc-index "unknown condition code: ~e" cc)]))

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
