#lang racket
(require "../main.rkt")

;; a/lib.asm 和 b/lib.asm 都是纯指令文件，自动变成匿名模块
;; 路径: (test a lib) 和 (test b lib)，不冲突
(define b (assemble-sexp
  `(link rv64 (rv_i)
     (file "test/a/lib.asm")
     (file "test/b/lib.asm")
     (file "test/main.asm"))))

(printf "~a bytes ✓\n" (bytes-length b))
(printf "a/lib → (test a lib), b/lib → (test b lib), 路径区分不冲突\n")
