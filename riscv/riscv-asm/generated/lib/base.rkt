#lang racket/base

;; ============================================================
;; 底层 base 宏表面
;;
;; 这是字段定义/指令定义的宏表面。具体位运算实现在 bit.rkt。
;; raw/rebuilt 层只依赖这里，不直接依赖实现模块。
;;
;; 所有宏最终都展开成 bit.rkt 里的函数调用；字段值本身仍然是
;; lambda，可以被 combine / make-instruction 组合。
;; ============================================================

(require (prefix-in impl: "bit.rkt"))

(provide bit
         bit-range
         bit-range-fixed
         combine
         bit-map
         make-instruction
         checked-field)

;; ------------------------------------------------------------
;; 字段原语
;; ------------------------------------------------------------

(define-syntax-rule (bit src dst)
  (impl:bit src dst))

;; (bit-range src-lo src-hi dst-lo)
(define-syntax-rule (bit-range src-lo src-hi dst-lo)
  (impl:bit-range src-lo src-hi dst-lo))

;; (bit-range-fixed lo hi value)
(define-syntax-rule (bit-range-fixed lo hi value)
  (impl:bit-range-fixed lo hi value))

;; (combine field ...)
(define-syntax-rule (combine field ...)
  (impl:combine field ...))

;; (bit-map (src . dst) ...)
(define-syntax-rule (bit-map mapping ...)
  (impl:bit-map mapping ...))

;; (make-instruction operands fixed)
(define-syntax-rule (make-instruction operands fixed)
  (impl:make-instruction operands fixed))

;; (checked-field name field min max [align])
(define (checked-field name field min max [align 1])
  (impl:checked-field name field min max align))
