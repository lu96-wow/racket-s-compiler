#lang racket/base

;; ============================================================
;; 指令元数据
;;
;; operands      : rebuilt 层的逻辑操作数
;; raw-operands  : raw 层的参数
;; fixed-fields  : ((lo hi value) ...)
;; aliases       : ((target source) ...)
;; ============================================================

(struct instruction-info
  (name
   extension
   width
   operands
   raw-operands
   fixed-fields
   aliases
   asm)
  #:transparent)

(provide instruction-info
         instruction-info?
         instruction-info-name
         instruction-info-extension
         instruction-info-width
         instruction-info-operands
         instruction-info-raw-operands
         instruction-info-fixed-fields
         instruction-info-aliases
         instruction-info-asm)
