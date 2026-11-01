#lang racket
;;; amd64/amd64-asm/plan.rkt
;;;
;;; Public instruction-plan facade.  Handwritten special families and the
;;; generated NASM table both resolve to the same resolved-plan shape:
;;;
;;;   operands -> constraints + form selection -> resolved-plan
;;;   resolved-plan -> plan-size (layout)
;;;   resolved-plan -> encode-plan (bytes only)

(require "sexp.rkt"
         "operand.rkt"
         "special.rkt"
         "insn-generic.rkt")

(provide (struct-out resolved-plan)
         instruction-plan
         plan-size
         encode-plan
         encode-instruction
         instruction-size
         known-instruction?
         instruction-arity

         ;; re-exported shared operand helpers
         immediate-form
         symbolic-immediate?
         choose-symbolic-immediate-forms)

;; SIZE is fixed when the plan is built.  DETAIL is the source-specific plan
;; (generic form plan or special byte plan); ENCODE is a policy-free thunk.
(struct resolved-plan (name size detail encode) #:transparent)

(define (plan-size plan)
  (resolved-plan-size plan))

(define (encode-plan plan)
  ((resolved-plan-encode plan)))

(define (special-plan name operands)
  (define bytes (special-encode name operands))
  (resolved-plan name (length bytes) (list 'special bytes)
                 (lambda () bytes)))

(define (generic-plan name operands)
  (define plan (generic-plan-instruction name operands))
  (resolved-plan name (generic-plan-size plan) (list 'generic plan)
                 (lambda () (generic-encode-plan plan))))

(define (prefix-plan pname inner)
  (unless (form? inner)
    (error 'instruction-plan "prefix body must be an instruction form: ~e" inner))
  (define inner-plan (instruction-plan (car inner) (cdr inner)))
  (define bytes (cons (prefix-byte pname) (encode-plan inner-plan)))
  (resolved-plan 'prefix (length bytes) (list 'prefix pname inner-plan)
                 (lambda () bytes)))

(define (instruction-plan name operands)
  (cond
    [(eq? name 'prefix)
     (match operands
       [(list pname inner) (prefix-plan pname inner)]
       [_ (error 'instruction-plan "prefix takes name and instruction: ~e"
                 operands)])]
    [(special-known? name) (special-plan name operands)]
    [(generic-instruction? name) (generic-plan name operands)]
    [else
     (error 'instruction-plan "unknown amd64 instruction: ~e" name)]))

(define (known-instruction? name)
  (or (eq? name 'prefix)
      (special-known? name)
      (generic-instruction? name)))

(define (instruction-arity name)
  (cond
    [(eq? name 'prefix) 2]
    [(special-arity name)]
    [else (generic-instruction-arity name)]))

(define (encode-instruction name operands)
  (list->bytes (encode-plan (instruction-plan name operands))))

;; ---------------------------------------------------------------------------
;; layout-facing size: prepare symbolic operands and use the same plan
;; ---------------------------------------------------------------------------

(define (operand-for-sizing op)
  (cond
    [(mem-form? op) (operand-for-sizing (parse-mem op))]
    [(and (mem? op) (not (exact-integer? (mem-disp op))))
     (case (mem-disp-width op)
       [(32) (struct-copy mem op [disp #x1000])]
       [else
        (error 'instruction-size
               "memory displacement must be resolved before sizing: ~e" op)])]
    [(and (immediate-form op) (symbolic-immediate? (cadr op)))
     (list (immediate-form op) #x1000)]
    [(and (address-expr? op) (not (exact-integer? op)))
     (list 'imm32 #x1000)]
    [else op]))

(define (branch-operands-for-sizing name operands)
  (case name
    [(jcc-short jcc-near)
     (list (car operands) 0)]
    [(jmp-short jmp-near call-near)
     (list 0)]
    [else operands]))

(define (instruction-size name operands)
  (cond
    [(eq? name 'prefix)
     (match operands
       [(list _pname inner)
        (unless (form? inner)
          (error 'instruction-size "prefix body must be an instruction form: ~e" inner))
        (+ 1 (instruction-size (car inner) (cdr inner)))]
       [_ (error 'instruction-size "prefix takes name and instruction: ~e" operands)])]
    [else
     (define branch? (memq name '(jmp-short jmp-near
                                  jcc-short jcc-near
                                  call-near)))
     (define prepared (choose-symbolic-immediate-forms name operands))
     (define ops (if branch?
                     (branch-operands-for-sizing name prepared)
                     (map operand-for-sizing prepared)))
     (plan-size (instruction-plan name ops))]))
