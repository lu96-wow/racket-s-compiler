#lang racket
;;; amd64-help/jump.rkt
;;;
;;; Direct/indirect call and jump forms.  Far/trampoline is intentionally not
;;; guessed: callers must provide scratch and a concrete policy.

(provide call-form
         call-indirect-form
         jump-indirect-form
         jump-far-form
         call-far-form)

(define (call-form target)
  (list 'call-near target))

(define (call-indirect-form rm)
  (list 'call-indirect rm))

(define (jump-indirect-form rm)
  (list 'jmp-indirect rm))

(define (jump-far-form target)
  (error 'jump-far-form
         "far jump/trampoline is not implemented yet (target: ~e)" target))

(define (call-far-form target)
  (error 'call-far-form
         "far call/trampoline is not implemented yet (target: ~e)" target))
