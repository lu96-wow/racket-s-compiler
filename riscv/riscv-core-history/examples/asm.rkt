#lang racket
;;; 纯汇编 raw 和 内嵌 asm 的形状示例。
;;; 这里只是数据，不实现分配/物化。

(provide raw-start
         asm-add)

;; 纯汇编：本来就是 machine 层，可以出现 label / j / b。
(define raw-start
  '(raw (start)
     (label (loop))
     (addi (native x10) (native x0) 1)
     (bne (loop) (native x10) (native x11))
     (j (start))))

;; 内嵌汇编：边界由 inputs / outputs / clobber 显式给出。
(define asm-add
  '(func (main)
     (vregs
       (($ a) (b64))
       (($ b) (b64))
       (($ r) (b64)))
     (entry b0)
     (block b0
       (asm
         (inputs
           (($ a) (native x10))
           (($ b) (native x11)))
         (outputs
           (($ r) (native x12)))
         (clobber
           (native x5))
         (code
           (label loop)
           (add (native x12) (native x10) (native x11))
           (bne loop (native x10) (native x11))))
       (term (return ($ r))))))
