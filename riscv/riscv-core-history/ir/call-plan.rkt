#lang racket
;;; ir/call-plan.rkt
;;;
;;; 扫描 machine IR，统计 call lowering 需要的 frame / scratch 信息。
;;;
;;; 第一版约定：
;;;   - 参数全部走 outgoing stack area；
;;;   - 每个参数一个 XLEN slot；
;;;   - 返回值最多 1 个。

(require racket/list
         "../core/sexp.rkt"
         "../core/num.rkt")

(provide (struct-out call-plan)
         plan-calls)

(struct call-plan
  (max-args       ; 最大参数个数
   outgoing-size  ; 对齐后的 outgoing area 字节数
   scratch-demand) ; call lowering 的保守 scratch 需求
  #:transparent)

(define (plan-calls func #:xlen [xlen 64] #:frame-align [frame-align 16])
  (unless (and (tagged? func 'func) (>= (length func) 2))
    (error 'call-plan "expected a func: ~e" func))
  (unless (memq xlen '(32 64))
    (error 'call-plan "xlen must be 32 or 64: ~e" xlen))
  (define word (quotient xlen 8))

  (define max-args 0)
  (define has-call? #f)

  (define (scan-op op)
    (cond
      [(and (form? op) (eq? (car op) 'call))
       (set! has-call? #t)
       (define args (cdddr op))
       (set! max-args (max max-args (length args)))]
      [else (void)]))

  (define (scan-term term)
    (define expr (cadr term))
    (match expr
      [(list 'return operands ...)
       (when (> (length operands) 1)
         (error 'call-plan
                "first version supports at most one return value, got: ~e"
                operands))]
      [_ (void)]))

  (for ([block (in-list (filter (lambda (x) (and (form? x) (eq? (car x) 'block)))
                                (cddr func)))])
    (define forms (cddr block))
    (define term (last forms))
    (for ([op (in-list (drop-right forms 1))])
      (scan-op op))
    (scan-term term))

  (call-plan max-args
             (align-up (* max-args word) frame-align)
             (if has-call? 2 1)))
