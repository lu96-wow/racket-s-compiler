#lang racket
;; 测试分支展开：用大量 nop 撑出 > 4KB 的向后跳转
;; 1025 条 addi = 4100 字节，超出 B-type 的 ±4096 范围
(define prog
  `(asm rv64 (rv_i)
     (label start)
     ,@(for/list ([i (in-range 1025)])
         `(addi zero zero 0))
     (bne start zero zero)
     (ebreak)))

(require "../../Asm_Build/main.rkt")
(define b (assemble-sexp prog))
(printf "bytes: ~a\n" (bytes-length b))
(display-to-file b "test/branch_expand.bin" #:exists 'replace)
