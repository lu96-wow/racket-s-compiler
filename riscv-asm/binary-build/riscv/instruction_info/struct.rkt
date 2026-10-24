#lang racket/base

;; ============================================================
;; 指令元数据
;;
;; name          : 指令名符号，例如 'add / 'c.addi4spn
;; extension     : 扩展名符号，例如 'rv_i
;; width         : 指令位宽（16 或 32），由 parcel 规则判定
;; size          : 指令字节数（2 或 4）
;; operands      : rebuilt 层的逻辑操作数
;; raw-operands  : raw 层的参数
;; fixed-fields  : ((lo hi value) ...)
;; aliases       : ((target source) ...)
;; ============================================================

(struct instruction-info
  (name
   extension
   width
   size
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
         instruction-info-size
         instruction-info-operands
         instruction-info-raw-operands
         instruction-info-fixed-fields
         instruction-info-aliases
         instruction-info-asm)
