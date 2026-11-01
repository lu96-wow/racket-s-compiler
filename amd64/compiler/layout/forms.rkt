#lang racket
;;; amd64/compiler/layout/forms.rkt
;;;
;;; item 分类、尺寸和对齐。item 形状来自 amd64/item.rkt，
;;; 真实指令尺寸来自 amd64/insn.rkt。layout 不依赖 encode。

(require "../item.rkt"
         "../../amd64-asm/insn.rkt")

(provide form? name? path? normalize-path

         make-segment segment? segment-name segment-kind segment-start segment-end segment-align
         parse-segment-form
         make-offset offset? offset-position offset-item
         make-anchor anchor? anchor-chain anchor-segment anchor-position
         make-request request? request-kind request-payload
         make-problem problem? problem-kind problem-detail

         label-form? label-chain
         comment-form?
         align-form? pad-form? bytes-form? fill-form? value-form?
         reserve-form? reserve-size
         value-width value-payload
         item-kind item-size item-kind-allowed-in?
         align-pad
         control-transfer-form? short-control-transfer-form? near-control-transfer-form?
         control-transfer-target control-transfer-range)


;; ---------------------------------------------------------------------------
;; Layout IR constructors/accessors
;; ---------------------------------------------------------------------------

(struct segment (name kind start end align) #:transparent)

(define (make-segment name kind start end align)
  (unless (symbol? name) (error 'make-segment "segment name must be a symbol: ~e" name))
  (unless (memq kind '(code data hole))
    (error 'make-segment "segment kind must be code/data/hole: ~e" kind))
  (unless (exact-integer? start)
    (error 'make-segment "segment start must be an integer: ~e" start))
  (unless (exact-integer? end)
    (error 'make-segment "segment end must be an integer: ~e" end))
  (unless (exact-positive-integer? align)
    (error 'make-segment "segment align must be positive: ~e" align))
  (segment name kind start end align))

(define (field-value key fields)
  (cond ((assq key fields) => cadr)
        [else #f]))

(define (parse-segment-form s)
  (unless (and (form? s) (eq? (car s) 'segment))
    (error 'parse-segment-form "bad segment form: ~e" s))
  (define fields (cdr s))
  (make-segment (field-value 'name fields)
                (field-value 'kind fields)
                (field-value 'start fields)
                (field-value 'end fields)
                (field-value 'align fields)))

(define (make-offset position item)
  (unless (exact-nonnegative-integer? position)
    (error 'make-offset "offset must be a non-negative integer: ~e" position))
  (list 'offset position item))

(define (offset? x)
  (and (form? x) (eq? (car x) 'offset) (= 3 (length x)) #t))
(define (offset-position x) (cadr x))
(define (offset-item x) (caddr x))

(define (make-anchor chain segment position)
  (list 'anchor (normalize-path chain) segment position))

(define (anchor? x)
  (and (form? x) (eq? (car x) 'anchor) (= 4 (length x)) #t))
(define (anchor-chain x) (cadr x))
(define (anchor-segment x) (caddr x))
(define (anchor-position x) (cadddr x))

(define (make-request kind . payload)
  (unless (symbol? kind)
    (error 'make-request "request kind must be a symbol: ~e" kind))
  (cons kind payload))
(define (request? x)
  (and (form? x) (symbol? (car x)) #t))
(define (request-kind x) (car x))
(define (request-payload x) (cdr x))

(define (make-problem kind . detail)
  (unless (symbol? kind)
    (error 'make-problem "problem kind must be a symbol: ~e" kind))
  (cons kind detail))
(define (problem? x)
  (and (form? x) (symbol? (car x)) #t))
(define (problem-kind x) (car x))
(define (problem-detail x) (cdr x))

(define (item-size target x)
  (cond
    [(label-form? x) 0]
    [(comment-form? x) 0]
    [(align-form? x) #f]
    [(pad-form? x) (cadr x)]
    [(bytes-form? x) (length (cdr x))]
    [(fill-form? x) (cadr x)]
    [(reserve-form? x) (reserve-size x)]
    [(value-form? x) (value-width x)]
    [else (instruction-size target (car x) (cdr x))]))

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
