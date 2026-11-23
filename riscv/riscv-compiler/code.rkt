#lang racket
;;; code.rkt
;;;
;;; backend 的代码输入契约。
;;;
;;; 前端把最终的块和物理 fallthrough 事实交到这里:
;;;
;;;   (code
;;;     (blocks
;;;       (block (<label-chain> ...) item ...)
;;;       ...)
;;;     (falls
;;;       (fall <from-index> <to-index>)
;;;       ...))
;;;
;;; 只保留 backend 需要的两样东西:
;;;   - blocks : 块身份(下标) + 块内 item
;;;   - falls  : 物理顺序上必须紧挨着的块对
;;;
;;; 没有 succ / root? / CFG。可达性、DCE、块顺序都由前端决定。

(require "sexp.rkt"
         "meta.rkt")

(provide code?
         code-blocks
         code-falls
         make-code
         block-head
         block-items
         make-block
         fall-from
         fall-to
         make-fall
         code->sexp
         sexp->code)

;; ---------------------------------------------------------------------------
;; 形状
;; ---------------------------------------------------------------------------

(define (code? x)
  (and (tagged-form? x 'code)
       (tagged-form? (ag 'blocks x) 'blocks)
       (tagged-form? (ag 'falls x) 'falls)))

(define (ag key x)
  (define row (and (form? x) (assq key (cdr x))))
  (and row (cons key (cdr row))))

(define (code-blocks c)
  (unless (code? c) (error 'code "expected code: ~e" c))
  (cdr (assoc 'blocks (cdr c))))

(define (code-falls c)
  (unless (code? c) (error 'code "expected code: ~e" c))
  (cdr (assoc 'falls (cdr c))))

(define (make-code blocks falls)
  (list 'code
        (cons 'blocks blocks)
        (cons 'falls falls)))

;; 块 = (block (<label-chain> ...) item ...)
(define (block-head b) (cadr b))
(define (block-items b) (cddr b))
(define (make-block head items) (cons 'block (cons head items)))

;; fall = (fall from to)
(define (fall-from f) (cadr f))
(define (fall-to f) (caddr f))
(define (make-fall from to) (list 'fall from to))

;; ---------------------------------------------------------------------------
;; 打印 / 读字面量
;; ---------------------------------------------------------------------------

(define (code->sexp c)
  (list 'code
        (cons 'blocks (code-blocks c))
        (cons 'falls (code-falls c))))

;; 收:
;;   (code (blocks ...) (falls ...))
;;   ((blocks ...) (falls ...))
;;   ((blocks ...) (flows ...))      ; 兼容旧的 blocks+flows 字面量: 只取 fallthrough
;;
;; 旧 flows 里的 succ / root? 不进入 code。
(define (sexp->code datum)
  (define fields
    (cond
      [(and (form? datum) (eq? (car datum) 'code)) (cdr datum)]
      [(and (form? datum) (eq? (car datum) 'program)) (cdr datum)]
      [(list? datum) datum]
      [else (error 'code "expected code / ((blocks ...) ...): ~e" datum)]))
  (define blocks-row (assoc 'blocks fields))
  (define falls-row (assoc 'falls fields))
  (define flows-row (assoc 'flows fields))
  (unless blocks-row
    (error 'code "code is missing (blocks ...): ~e" datum))
  (define blocks (cdr blocks-row))
  (define falls
    (cond
      [falls-row (cdr falls-row)]
      [flows-row (flows->falls (cdr flows-row))]
      [else '()]))
  (make-code blocks falls))

;; 旧 flow: (flow (succ ...) (fallthrough id|#f) (root? bool))
(define (flows->falls flows)
  (for/list ([f (in-list flows)]
             [i (in-naturals)]
             #:do [(define ft (flow-fallthrough f))]
             #:when ft)
    (make-fall i ft)))

(define (flow-fallthrough f)
  (define row (and (form? f) (assq 'fallthrough (cdr f))))
  (and row (cadr row)))
