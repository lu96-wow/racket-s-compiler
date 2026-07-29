#lang racket
;; 向前跳转，目标在 4100 字节之外，触发松弛迭代
(define prog
  `(asm rv64 (rv_i)
     (bne far zero zero)          ;; 向前跳转 > 4KB，第一遍是未知大小
     ,@(for/list ([i (in-range 1025)])
         `(addi zero zero 0))
     (label far)
     (ebreak)))

(require "../../Asm_Build/main.rkt")
(define b (assemble-sexp prog))
(printf "bytes: ~a\n" (bytes-length b))
(display-to-file b "test/branch_forward.bin" #:exists 'replace)
