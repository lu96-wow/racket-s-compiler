#lang racket
;;; amd64-help/la.rkt
;;;
;;; Address-loading forms.  Near forms are `lea` (RIP-relative or base+disp);
;;; absolute/constant loading reuses li.  Whether a symbolic RIP-relative
;;; displacement is reachable is checked by layout, not here.

(require "../amd64-asm/sexp.rkt"
         "../amd64-asm/target.rkt"
         "../amd64-asm/insn.rkt"
         "li.rkt")

(provide la-pcrel
         la-frame
         la-abs
         la-size)

(define (la-pcrel dst expr)
  (unless (address-expr? expr)
    (error 'la-pcrel "address expression expected: ~e" expr))
  (list 'lea dst
        (list 'b64
              (list 'base 'rip)
              (list 'disp expr))))

(define (la-frame dst base disp)
  (unless (and (symbol? base) (exact-integer? disp))
    (error 'la-frame "frame address needs a base symbol and integer disp: ~e ~e"
           base disp))
  (list 'lea dst
        (list 'b64
              (list 'base base)
              (list 'disp disp))))

(define (la-abs dst value)
  (li->form dst value))

(define (la-size dst value #:target [target target-amd64])
  (define form (la-abs dst value))
  (instruction-size target (car form) (cdr form)))
