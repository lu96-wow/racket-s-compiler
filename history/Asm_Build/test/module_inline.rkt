#lang racket
(require "../main.rkt")

;; 内联模块 + link + 全量导入
(define b
  (assemble-sexp
    `(link rv64 (rv_i)
       (module math
         (provide add_one sub_one)
         (label add_one) (addi a0 a0 1) (jalr zero ra 0)
         (label sub_one) (addi a0 a0 -1) (jalr zero ra 0))
       (module main
         (require math)             ;; 全量导入
         (label main)
         (li a0 10)
         (jal ra add_one)
         (jal ra sub_one)
         (ebreak)))))

(printf "inline link + require-all: ~a bytes\n" (bytes-length b))
