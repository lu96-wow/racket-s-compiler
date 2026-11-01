#lang racket
;;; amd64/amd64-asm/encoding-plan.rkt
;;;
;;; Low-level, policy-free encoding plan shared by handwritten special forms.
;;; It fixes prefixes/opcode/ModR/M/displacement/immediate once; size and bytes
;;; are derived from the same fields.

(require "insn-core.rkt")

(provide (struct-out encoding-plan)
         literal-plan
         rm-plan
         encoding-plan-size
         encoding-plan-bytes)

(struct encoding-plan
  (wait? segment-prefix prefixes rex opcode rm-enc imm)
  #:transparent)

(define (literal-plan bytes)
  (encoding-plan #f #f '() #f bytes #f '()))

(define (rm-plan width regs rm-enc opcode [imm '()] [extra-prefixes '()])
  (define segment-prefix (rm-encoding-seg rm-enc))
  (define size-prefix (if (= width 16) (list #x66) '()))
  (define rex
    (make-rex (= width 64)
              regs
              (rm-encoding-rex-r rm-enc)
              (rm-encoding-rex-x rm-enc)
              (rm-encoding-rex-b rm-enc)))
  (encoding-plan #f segment-prefix
                 (append size-prefix extra-prefixes)
                 rex opcode rm-enc imm))

(define (encoding-plan-size plan)
  (define rm-enc (encoding-plan-rm-enc plan))
  (+ (if (encoding-plan-wait? plan) 1 0)
     (if (encoding-plan-segment-prefix plan) 1 0)
     (length (encoding-plan-prefixes plan))
     (if (encoding-plan-rex plan) 1 0)
     (length (encoding-plan-opcode plan))
     (if rm-enc 1 0)
     (if (and rm-enc (rm-encoding-sib rm-enc)) 1 0)
     (if rm-enc (length (rm-encoding-disp rm-enc)) 0)
     (length (encoding-plan-imm plan))))

(define (encoding-plan-bytes plan)
  (define rm-enc (encoding-plan-rm-enc plan))
  (bytes*
   (if (encoding-plan-wait? plan) (list #x9b) '())
   (if (encoding-plan-segment-prefix plan)
       (list (encoding-plan-segment-prefix plan))
       '())
   (encoding-plan-prefixes plan)
   (let ([rex (encoding-plan-rex plan)])
     (if rex (list rex) '()))
   (encoding-plan-opcode plan)
   (if rm-enc (list (rm-encoding-modrm rm-enc)) '())
   (if (and rm-enc (rm-encoding-sib rm-enc))
       (list (rm-encoding-sib rm-enc))
       '())
   (if rm-enc (rm-encoding-disp rm-enc) '())
   (encoding-plan-imm plan)))
