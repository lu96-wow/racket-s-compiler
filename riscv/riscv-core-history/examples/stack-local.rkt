#lang racket
;;; stack-first 示例：变量 x 在栈上，t 是表达式临时值。
;;; 所有栈访问都显式写 addr / load / store。

(provide stack-local-virtual
         stack-local-allocation
         stack-local-frame)

(define stack-local-virtual
  '(func (main)
     (vregs
       (($ x) (b64) (address-taken))
       (($ p) (ptr))
       (($ t) (b64)))
     (entry b0)
     (block b0
       (const ($ t) 42)
       (addr ($ p) ($ x))
       (store ($ p) 0 ($ t) (b64))
       (load ($ t) ($ p) 0 (b64))
       (term (return ($ t))))))

(define stack-local-allocation
  '(allocation
     (($ x) (slot 0))
     (($ p) (native x10))
     (($ t) (native x11))))

(define stack-local-frame
  '(frame
     (size 32)
     (header 16)
     (outgoing 0)
     (align 16)
     (slots
       (slot 0 (offset 24) (size 8) (align 8)))))
