#lang racket
;;; amd64/layout/forms.rkt
;;;
;;; item 分类、尺寸和对齐。item 形状来自 amd64/item.rkt，
;;; 真实指令尺寸来自 amd64/insn.rkt。layout 不依赖 encode。

(require "../item.rkt"
         "../insn.rkt")

(provide form? name? path? normalize-path
         label-form? label-chain
         comment-form?
         align-form? pad-form? bytes-form? fill-form? value-form?
         value-width value-payload
         item-kind item-size
         align-pad
         control-transfer-form? short-control-transfer-form? near-control-transfer-form?
         control-transfer-target control-transfer-range)

(define (item-size x)
  (cond
    [(label-form? x) 0]
    [(comment-form? x) 0]
    [(align-form? x) #f]
    [(pad-form? x) (cadr x)]
    [(bytes-form? x) (length (cdr x))]
    [(fill-form? x) (cadr x)]
    [(value-form? x) (value-width x)]
    [else (instruction-size (car x) (cdr x))]))

(define (align-pad absolute-address alignment)
  (modulo (- alignment (modulo absolute-address alignment)) alignment))

(define control-transfer-mnemonics
  '(jmp-short jmp-near jcc-short jcc-near call-near))

(define (control-transfer-form? x)
  (and (form? x) (memq (car x) control-transfer-mnemonics) #t))

(define (short-control-transfer-form? x)
  (and (control-transfer-form? x)
       (memq (car x) '(jmp-short jcc-short))
       #t))

(define (near-control-transfer-form? x)
  (and (control-transfer-form? x)
       (memq (car x) '(jmp-near jcc-near call-near))
       #t))

(define (control-transfer-target x) (last x))

(define (control-transfer-range x)
  (case (car x)
    [(jmp-short jcc-short) '(-128 . 127)]
    [(jmp-near jcc-near call-near) '(-2147483648 . 2147483647)]
    [else #f]))
