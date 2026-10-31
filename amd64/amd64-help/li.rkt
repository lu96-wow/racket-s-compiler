#lang racket
;;; amd64-help/li.rkt
;;;
;;; `li` 的展开规则。它是“取地址/装常量”的辅助层，不是编码器：
;;;   - 整数     -> mov
;;;   - 地址表达式 -> RIP-relative lea
;;;
;;; 超出 ±2GiB 的地址不在这一层判断；由 layout 的 RIP-relative 检查处理。

(require "../amd64-asm/sexp.rkt")

(provide li->form)

(define (li->form dst value)
  (cond
    [(exact-integer? value)
     (list 'mov dst value)]
    [(address-expr? value)
     (list 'lea dst
           (list 'b64
                 (list 'base 'rip)
                 (list 'disp value)))]
    [else
     (error 'li->form
            "li value is neither an integer nor an address expression: ~e"
            value)]))
