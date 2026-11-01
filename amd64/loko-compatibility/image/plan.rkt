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
         choose-loko-linux-image-plan
         plan-clauses plan-field segment-align-for
         loko-linux-stack-start
         loko-linux-stack-size
         loko-linux-heap-start
         loko-linux-heap-size)

(define page-size 4096)
(define loko-linux-stack-start (expt 2 40))      ;1 TiB
(define loko-linux-stack-size (* 2 1024 1024))   ;2 MiB
(define loko-linux-heap-start (+ loko-linux-stack-start loko-linux-stack-size))
(define loko-linux-heap-size (* 16 1024 1024))   ;16 MiB

(define (materialized-region id section perm load)
  (list 'region
        (list 'id id)
        (list 'content (if (eq? id 'bss) 'reserved 'materialized))
        (list 'section section)
        (list 'perm perm)
        (list 'load load)))

(define (reserved-region id section perm load start size)
  (list 'region
        (list 'id id)
        (list 'content 'reserved)
        (list 'section section)
        (list 'perm perm)
        (list 'load load)
        (list 'start start)
        (list 'size size)))

;; ---------------------------------------------------------------------------
;; plan 的读取
;; ---------------------------------------------------------------------------

(define (plan-clauses plan key)
  (for/list ([c (in-list plan)]
             #:when (and (pair? c) (eq? (car c) key)))
    c))

(define (plan-field clause key)
  (cond ((assq key (cdr clause)) => cadr)
        [else #f]))

;; 一个 section 的对齐要求从哪来:
;;   - 它自己的 region 的 (align …)  —— section 自身的对齐(.text 16 / .data 8 …)
;;   - 它所在 load 的 (align …)      —— 整个 load 的对齐(= 页边界)
;; 取两者的 max: 段起点满足更严的那个之后, 两个约束都成立。
;; 这是"页边界"这类镜像约束进入地址分配的唯一入口。
;; 都没有 -> 1(计划不关心, 紧凑排即可)。
(define (segment-align-for plan name)
  (define region
    (for/first ([r (in-list (plan-clauses plan 'region))]
                #:when (or (eq? (plan-field r 'id) name)
                           (equal? (plan-field r 'section) (format ".~a" name))))
      r))
  (define load-id (and region (plan-field region 'load)))
  (define load
    (and load-id
         (for/first ([l (in-list (plan-clauses plan 'load))]
                     #:when (eq? (plan-field l 'id) load-id))
           l)))
  (max (or (and region (plan-field region 'align)) 1)
       (or (and load (plan-field load 'align)) 1)))

(define (choose-loko-linux-image-plan symbols declared-plan)
  (cond
    [(pair? declared-plan) declared-plan]
    [(for/or ([s (in-list symbols)])
       (equal? (cadr s) '(elf-entry)))
     (loko-linux-image-plan)]
    [else '()]))

;; 每个 load 单独一页: text/data/bss 的权限不同, 共用一页时内核的页映射
;; 会让后一个覆盖前一个(实测会直接 SIGSEGV)。这个约束以 (align …) 的
;; 形式流进 loko-image 的 layout-spec, 由 layout 求解地址时兑现。
(define (load-clause id)
  (list 'load (list 'id id) (list 'align page-size)))

(define (loko-linux-image-plan)
  (list
   (list 'entry (list 'elf-entry))
   (load-clause 'text)
   (load-clause 'data)
   (load-clause 'bss)
   (materialized-region 'text ".text" 'r-x 'text)
   (materialized-region 'data ".data" 'r-- 'data)
   (materialized-region 'bss ".bss" 'rw- 'bss)
   ;; The first page of the stack is a guard page.
   (reserved-region 'stack0 ".stack0" 'rw- 'stack
             (+ loko-linux-stack-start page-size) (- loko-linux-stack-size page-size))
   (reserved-region 'heap0 ".heap0" 'rw- 'heap loko-linux-heap-start loko-linux-heap-size)))
