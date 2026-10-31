#lang racket
;;; amd64/loko-compatibility/ir.rkt
;;;
;;; loko-ir 的共享 s-expression 形状和访问器。
;;;
;;;   (loko-ir
;;;     (origin 地址|#f)
;;;     (symbols (symbol start end section misc) ...)
;;;     (comms (comm name size align) ...)
;;;     (sections
;;;       (section (name 名字)
;;;                (kind code|data|bss)
;;;                (modes (item下标 mode) ...)
;;;                (items item ...))
;;;       ...))
;;;
;;; 这里只提供形状/字段，不解释 Loko 语义。

(require "../amd64-asm/sexp.rkt")

(provide make-loko-ir
         loko-ir?
         ir-field ir-value ir-list
         make-section
         section?
         section-field section-name section-kind section-modes section-items)

(define (loko-ir? x)
  (and (form? x) (eq? (car x) 'loko-ir)))

(define (ir-field ir key)
  (and (loko-ir? ir)
       (assq key (cdr ir))))

(define (ir-value ir key)
  (define p (ir-field ir key))
  (and p (cadr p)))

(define (ir-list ir key)
  (define p (ir-field ir key))
  (and p (cdr p)))

(define (make-loko-ir origin symbols comms sections)
  (list 'loko-ir
        (list 'origin origin)
        (cons 'symbols symbols)
        (cons 'comms comms)
        (cons 'sections sections)))

(define (section? x)
  (and (form? x) (eq? (car x) 'section)))

(define (section-field section key)
  (and (section? section)
       (assq key (cdr section))))

(define (section-name section)
  (define p (section-field section 'name))
  (and p (cadr p)))

(define (section-kind section)
  (define p (section-field section 'kind))
  (and p (cadr p)))

(define (section-modes section)
  (define p (section-field section 'modes))
  (and p (cdr p)))

(define (section-items section)
  (define p (section-field section 'items))
  (and p (cdr p)))

(define (make-section name kind modes items)
  (list 'section
        (list 'name name)
        (list 'kind kind)
        (cons 'modes modes)
        (cons 'items items)))
