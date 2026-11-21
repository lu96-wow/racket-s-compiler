#lang racket
;;; 最小例子：一个 block、一个 return。
;;; 只用于形状/验证测试，没有实现。

(provide minimal-virtual
         minimal-allocation
         minimal-machine)

(define minimal-virtual
  '(func (main)
     (vregs
       (($ a) (b8))
       (($ b) (b8))
       (($ t) (b64)))
     (entry b0)
     (block b0
       (add ($ t) ($ a) ($ b))
       (term (return ($ t))))))

(define minimal-allocation
  '(allocation
     (($ a) (native x10))
     (($ b) (native x11))
     (($ t) (native x12))))

(define minimal-machine
  '(func (main)
     (entry b0)
     (block b0
       (add (native x12) (native x10) (native x11))
       (term (return (native x12))))))
