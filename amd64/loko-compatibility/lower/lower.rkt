#lang racket
;;; amd64/loko-compatibility/lower/lower.rkt
;;;
;;; lower 层的组合入口：找伪寄存器 -> 活性 -> 分配 -> 替换。
;;;
;;; 输入是 program-items（text 侧 item 列表），输出还是 item 列表：
;;;
;;;   (lower-result
;;;     (items item ...)
;;;     (allocation (下标 . 寄存器) ...)
;;;     (problems problem ...))
;;;
;;; 也可以传入 #:allocation 使用调用方已经算好的分配；这时跳过
;;; liveness/allocate，只做替换。
;;;
;;; 调用点的 save/restore 注记由 calls.rkt 先展开；本层仍不处理：
;;;   - spill 到栈；
;;;   - frame allocation；
;;;   - %origin/%section/%comm/%call。
;;;
;;; 这些都属于后续层；未着色的伪寄存器会以 problem 形式保留下来，
;;; 不会被静默丢掉。

(require "pseudo.rkt"
         "liveness.rkt"
         "allocate.rkt")

(provide (struct-out lower-result)
         lower-program-items)

(struct lower-result (items allocation problems) #:transparent)

(define (lower-problem kind . detail)
  (cons 'problem (cons kind detail)))

(define (allocation->hash allocation)
  (cond
    [(hash? allocation) allocation]
    [(list? allocation)
     (for/hash ([p (in-list allocation)])
       (values (car p) (allocation-pair-value p)))]
    [else
     (error 'lower-program-items "allocation must be a hash or alist: ~e" allocation)]))

(define (allocation-hash->alist allocation)
  (sort (for/list ([(pseudo register) (in-hash allocation)])
          (cons pseudo register))
        < #:key car))

(define (lower-program-items items
                             #:allocation [allocation #f]
                             #:available [available default-available-registers])
  (define-values (alloc uncolored)
    (cond
      [allocation (values (allocation->hash allocation) '())]
      [else
       (define lv (compute-liveness items))
       (define result (allocate-pseudo-registers lv items #:available available))
       (values (allocation-result-allocation result)
               (allocation-result-uncolored result))]))

  ;; 逐 item 替换；收集所有缺失伪寄存器，便于一次报告。
  (define missing-all (make-hash))
  (define lowered
    (for/list ([item (in-list items)])
      (define-values (out missing) (substitute-pseudo-registers item alloc))
      (for ([n (in-list missing)]) (hash-set! missing-all n #t))
      out))

  (define problems
    (append
     (for/list ([n (in-list (sort (hash-keys missing-all) <))]
                #:unless (memv n uncolored))
       (lower-problem 'unallocated-pseudo n))
     (for/list ([n (in-list uncolored)])
       (lower-problem 'uncolored-pseudo n))))

  (lower-result lowered (allocation-hash->alist alloc) problems))
