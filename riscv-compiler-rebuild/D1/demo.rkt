#lang racket
;;; D1/demo.rkt -- 数据定义: rich 数据 -> 核心数据 item

(require "expand.rkt")

(define src
  '((label data1 table)
    (b8 1)
    (b16 258)
    (b32 #x12345678)
    (b64 -1)
    (utf-string "abc")
    (utf-stringz "hi")
    (b8-array 4096 0)         ; 4096 个 0: 仍是一条 item
    (b32-array 4 1 2)         ; 1 2 2 2
    (align 8)
    (bytes 0 1 2)))

(displayln ";; 数据源")
(for ([it (in-list src)]) (displayln (format "  ~s" it)))

(newline)
(displayln ";; D1 输出 (label / bytes / fill / align; 小端已定序)")
(for ([it (in-list (expand-data src))]) (displayln (format "  ~s" it)))
