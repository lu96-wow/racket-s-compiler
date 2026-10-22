#lang racket
(require "../main.rkt")

;; 深度嵌套 require 路径修复验证
(printf "深度嵌套: ")
(define b1 (assemble-sexp
  (list 'asm 'rv64 '(rv_i)
    (list 'module 'a
      (list 'module 'b
        (list 'module 'c
          (list 'require '(a b d) 'sym)
          '(label entry) '(jal ra sym) '(ebreak))
        (list 'module 'd
          '(provide sym)
          '(label sym) '(addi a0 a0 1) '(jalr zero ra 0)))))))
(printf "~a bytes\n" (bytes-length b1))

;; module+ 继承父私有符号
(printf "module+ 继承: ")
(define b2 (assemble-sexp
  (list 'asm 'rv64 '(rv_i)
    (list 'module 'lib
      '(label priv) '(addi a0 a0 1) '(jalr zero ra 0)
      (list 'module+ 'test
        '(label check) '(jal ra priv) '(jalr zero ra 0))
      '(label pub) '(jal ra priv) '(jalr zero ra 0))
    '(label main) '(ebreak))))
(printf "~a bytes\n" (bytes-length b2))
