#lang racket
;;; 分配表形状示例：寄存器 / slot / scratch。
;;; 不涉及 C ABI，也不涉及 layout。

(provide register-allocation
         spill-allocation
         spill-scratch)

(define register-allocation
  '(allocation
     (($ a) (native x10))
     (($ b) (native x11))
     (($ t) (native x12))))

(define spill-allocation
  '(allocation
     (($ a) (native x10))
     (($ b) (slot 0))
     (($ t) (native x12))))

(define spill-scratch
  '(scratch (native x5)))
