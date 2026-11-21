#lang racket
;;; module / provide / require 的形状示例。
;;; 这里只是数据，不实现解析。

(provide module-source
         module-resolved
         implicit-root)

;; 源码侧：两个 module，app 通过 require 看到 (f)，调用写 (global (f))。
(define module-source
  '((module (lib util)
      (provide (f))
      (func (f)
        (vregs
          (($ a) (b64)))
        (entry b0)
        (block b0
          (term (return ($ a))))))

    (module (app)
      (require (lib util))
      (func (main)
        (vregs
          (($ r) (b64)))
        (entry b0)
        (block b0
          (call ($ r) (global (f)))
          (term (return ($ r))))))))

;; 解析后的形状：没有 module，只有完整链。
(define module-resolved
  '((func (lib util f)
      (vregs
        (($ a) (b64)))
      (entry b0)
      (block b0
        (term (return ($ a)))))

    (func (app main)
      (vregs
        (($ r) (b64)))
      (entry b0)
      (block b0
        (call ($ r) (global (lib util f)))
        (term (return ($ r)))))))

;; 单文件隐式根模块：没有 module 壳，全部全局名默认导出。
(define implicit-root
  '(func (main)
     (vregs
       (($ a) (b64)))
     (entry b0)
     (block b0
       (term (return ($ a))))))
