#lang racket
;;; amd64/compiler/layout/forms.rkt
;;;
;;; item 分类、尺寸和对齐。item 形状来自 amd64/item.rkt，
;;; 真实指令尺寸来自 amd64/insn.rkt。layout 不依赖 encode。

(require "../item.rkt"
         "../../amd64-asm/insn.rkt")

(provide form? name? path? normalize-path
         label-form? label-chain
         comment-form?
         align-form? pad-form? bytes-form? fill-form? value-form?
         reserve-form? reserve-size
         value-width value-payload
         item-kind item-size item-kind-allowed-in?
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
    [(reserve-form? x) (reserve-size x)]
    [(value-form? x) (value-width x)]
    [else (instruction-size (car x) (cdr x))]))

(define (align-pad absolute-address alignment)
  (modulo (- alignment (modulo absolute-address alignment)) alignment))

;; 段 kind -> 它收哪些 item 类。
;; code 段可以放数据(ELF/multiboot header、跳转表…), 这是本后端的事实;
;; hole 段只收位置类: 洞里的地址没有字节可对应。
(define (item-kind-allowed-in? ik kind)
  (and (case kind
         [(code) (memq ik '(marker align pad materialized code))]
         [(data) (memq ik '(marker align pad materialized))]
         [(hole) (memq ik '(marker align space))]
         [else #f])
       #t))

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
