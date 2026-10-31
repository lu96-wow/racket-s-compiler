#lang racket
;;; amd64/layout/forms.rkt
;;;
;;; item 分类、尺寸和对齐。代码 item 的尺寸由 encode/insn.rkt 的
;;; instruction-size 决定；布局层不重复实现 x86 编码。

(require "../sexp.rkt"
         "../encode/insn.rkt")

(provide form? name? path? normalize-path
         label-form? align-form? pad-form? bytes-form? fill-form? value-form?
         value-width value-payload
         item-kind item-size
         align-pad
         label-chain
         branch-form? short-branch-form? near-branch-form?
         branch-target branch-range)

(define (label-form? x)
  (and (form? x) (eq? (car x) 'label) (path? (cdr x))))

(define (label-chain x) (cdr x))

(define (align-form? x)
  (and (form? x) (eq? (car x) 'align) (= 2 (length x))
       (exact-positive-integer? (cadr x))))

(define (pad-form? x)
  (and (form? x) (eq? (car x) 'pad) (= 2 (length x))
       (exact-nonnegative-integer? (cadr x))))

(define (byte? x) (and (exact-integer? x) (<= 0 x 255)))

(define (bytes-form? x)
  (and (form? x) (eq? (car x) 'bytes) (andmap byte? (cdr x))))

(define (fill-form? x)
  (and (form? x) (eq? (car x) 'fill) (= 3 (length x))
       (exact-nonnegative-integer? (cadr x)) (byte? (caddr x))))

(define (value-width x) (cadr x))
(define (value-payload x) (caddr x))

(define (value-form? x)
  (and (form? x) (eq? (car x) 'value) (= 3 (length x))
       (memq (value-width x) '(1 2 4 8))))

(define (item-kind x)
  (cond
    [(label-form? x) 'marker]
    [(or (align-form? x) (pad-form? x)) 'both]
    [(or (bytes-form? x) (fill-form? x) (value-form? x)) 'data]
    [else 'code]))

(define (item-size x)
  (cond
    [(label-form? x) 0]
    [(align-form? x) #f]
    [(pad-form? x) (cadr x)]
    [(bytes-form? x) (length (cdr x))]
    [(fill-form? x) (cadr x)]
    [(value-form? x) (value-width x)]
    [else (instruction-size (car x) (cdr x))]))

(define (align-pad absolute-address alignment)
  (modulo (- alignment (modulo absolute-address alignment)) alignment))

(define branch-mnemonics '(jmp-short jmp-near jcc-short jcc-near call-near))

(define (branch-form? x)
  (and (form? x) (memq (car x) branch-mnemonics) #t))

(define (short-branch-form? x)
  (and (branch-form? x) (memq (car x) '(jmp-short jcc-short)) #t))

(define (near-branch-form? x)
  (and (branch-form? x) (memq (car x) '(jmp-near jcc-near call-near)) #t))

(define (branch-target x) (last x))

(define (branch-range x)
  (case (car x)
    [(jmp-short jcc-short) '(-128 . 127)]
    [(jmp-near jcc-near call-near) '(-2147483648 . 2147483647)]
    [else #f]))
