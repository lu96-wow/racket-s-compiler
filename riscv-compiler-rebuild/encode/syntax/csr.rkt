#lang racket
;;; encode/syntax/csr.rkt
;;;
;;; CSR 名字 -> 12 位编号。
;;; 数据表在 csr-table.rkt (由 riscv-opcodes/csrs.csv 生成)。
;;; rv32 专用的高位 CSR 在 csr32-table.rkt, 等 target profile 做了再启用。
;;; 数值 0..4095 原样透传, 范围检查仍然交给 riscv-asm 的 csr 字段。

(require "csr-table.rkt")

(provide csr-value)

(define (csr-value x)
  (cond
    [(exact-integer? x) x]
    [(symbol? x)
     (hash-ref csr-table x
               (lambda ()
                 (error 'encode-instruction "unknown CSR: ~a" x)))]
    [else
     (error 'encode-instruction "CSR must be a symbol or an integer: ~e" x)]))
