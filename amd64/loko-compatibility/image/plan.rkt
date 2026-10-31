#lang racket
;;; amd64/loko-compatibility/image/plan.rkt
;;;
;;; Loko Linux 镜像的声明式 `%elf` 计划。
;;;
;;; 编译器只产生 text/data/bss 三个 build segment；stack0 和 heap0 是
;;; Loko 运行时约定的固定地址区间，不是程序字节，因此作为 reserved
;;; region 交给 amd64-elf 的 plan 处理。
;;;
;;; 这些常量必须与 Loko 的 arch/amd64/memory.sls 保持一致。

(provide loko-linux-image-plan
         loko-linux-image-plan-for
         loko-linux-stack-start
         loko-linux-stack-size
         loko-linux-heap-start
         loko-linux-heap-size)

(define page-size 4096)
(define loko-linux-stack-start (expt 2 40))      ;1 TiB
(define loko-linux-stack-size (* 2 1024 1024))   ;2 MiB
(define loko-linux-heap-start (+ loko-linux-stack-start loko-linux-stack-size))
(define loko-linux-heap-size (* 16 1024 1024))   ;16 MiB

(define (region id section perm load)
  (list 'region
        (list 'id id)
        (list 'content (if (eq? id 'bss) 'reserved 'materialized))
        (list 'section section)
        (list 'perm perm)
        (list 'load load)))

(define (reserved id section perm load start size)
  (list 'region
        (list 'id id)
        (list 'content 'reserved)
        (list 'section section)
        (list 'perm perm)
        (list 'load load)
        (list 'start start)
        (list 'size size)))

(define (loko-linux-image-plan-for symbols declared-plan)
  (cond
    [(pair? declared-plan) declared-plan]
    [(for/or ([s (in-list symbols)])
       (equal? (cadr s) '(elf-entry)))
     (loko-linux-image-plan)]
    [else '()]))

(define (loko-linux-image-plan)
  (list
   (list 'entry (list 'elf-entry))
   (region 'text ".text" 'r-x 'text)
   (region 'data ".data" 'r-- 'data)
   (region 'bss ".bss" 'rw- 'bss)
   ;; The first page of the stack is a guard page.
   (reserved 'stack0 ".stack0" 'rw- 'stack
             (+ loko-linux-stack-start page-size) (- loko-linux-stack-size page-size))
   (reserved 'heap0 ".heap0" 'rw- 'heap loko-linux-heap-start loko-linux-heap-size)))
