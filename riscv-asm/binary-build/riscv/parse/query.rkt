#lang racket/base

(require "struct.rkt")

;; ============================================================
;; 固定位段查询
;; ============================================================

(define (fixed-bit-value fixed-fields bit)
  (for/first ([ff (in-list fixed-fields)]
              #:when (<= (fixed-field-lo ff) bit (fixed-field-hi ff)))
    (bitwise-and
     (arithmetic-shift (fixed-field-value ff)
                       (- (- bit (fixed-field-lo ff))))
     1)))

;; RISC-V 编码 bit1..0：11 表示 32 位，其余表示 16 位压缩指令。
;; 如果源定义没有固定这两位，直接报错，不做默认猜测。
(define (instruction-width idef)
  (define fixed-fields (instruction-def-fixed-fields idef))
  (define b0 (fixed-bit-value fixed-fields 0))
  (define b1 (fixed-bit-value fixed-fields 1))
  (unless (and b0 b1)
    (error 'instruction-width
           "instruction ~a does not fix opcode bits 0 and 1"
           (instruction-def-name idef)))
  (if (and (= b0 1) (= b1 1)) 32 16))

(provide fixed-bit-value
         instruction-width)
