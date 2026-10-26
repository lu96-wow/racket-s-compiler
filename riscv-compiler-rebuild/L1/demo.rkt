#lang racket
;;; L1/demo.rkt -- 模块展平 + 链式查表

(require "flatten.rkt")

(define src
  '((module main
      (label entry)
      (jal x0 (helper))          ; 链式: (main helper)
      (label helper)
      (jal x0 (util)))           ; (main util) 没有 -> 退到 (util)
    (label util)
    (module util2                ; 嵌套模块
      (label helper)
      (jalra x0 (helper)))))     ; (util2 helper)

(displayln ";; 展平前")
(for ([m (in-list src)]) (displayln (format "  ~s" m)))

(define-values (flat table) (flatten-items src))

(newline)
(displayln ";; 展平后 (label 的链带完整作用域前缀, 引用改成完整链)")
(for ([it (in-list flat)]) (displayln (format "  ~s" it)))

(newline)
(displayln ";; 名字表 (链 -> 位置序号)")
(for ([(path slot) (in-hash table)])
  (displayln (format "  ~s -> ~a" path slot)))

(newline)
(displayln (format "程序形状: ~s" (flatten-program src)))
