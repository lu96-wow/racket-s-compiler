#lang racket
;;; encode/syntax/csr.rkt
;;;
;;; CSR 名字 -> 12 位编号。
;;; 数据表在 csr-table.rkt (由 riscv-opcodes/csrs.csv 生成)。
;;; rv32 专用的高位 CSR 在 csr32-table.rkt; 由当前 target 的 XLEN 选择。
;;; 数值 0..4095 原样透传, 范围检查仍然交给 riscv-asm 的 csr 字段。

(require racket/hash
         "csr-table.rkt"
         "csr32-table.rkt"
         "../../target.rkt")

(provide csr-value)

(define rv32-csr-table (hash-union csr-table csr32-table))

(define (csr-table-for-target target)
  (if (eq? (target-xlen target) 'rv32)
      rv32-csr-table
      csr-table))

(define (csr-value target x)
  (cond
    [(exact-integer? x) x]
    [(symbol? x)
     (hash-ref (csr-table-for-target target) x
               (lambda ()
                 (error 'encode-instruction "unknown CSR: ~a" x)))]
    [else
     (error 'encode-instruction "CSR must be a symbol or an integer: ~e" x)]))
