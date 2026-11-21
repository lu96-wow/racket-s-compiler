#lang racket
;;; 全局 data 段示例：对齐、整数、字节、fill。
;;; data 不进入 virtual IR；由 program-layout 放置，encode-program 写出。

(provide data-table)

(define data-table
  '(data (d table)
     (align 8)
     (value 8 7)
     (bytes 1 2 3)
     (align 8)
     (value 8 9)
     (fill 8 0)))
