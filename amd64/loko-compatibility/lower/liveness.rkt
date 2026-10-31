#lang racket
;;; amd64/loko-compatibility/lower/liveness.rkt
;;;
;;; 伪寄存器的基本块活性分析。
;;;
;;; 输入可以是 (analyze ...) 的 program，也可以是扁平 item 列表。
;;; 输出所有块、每条指令之后的 live-out 集合，以及出现过的伪寄存器。
;;;
;;; 这个分析只服务于 lower：它不知道物理寄存器，也不模拟调用约定。
;;; 调用点的 save/restore 注记会作为普通 item 穿过；调用本身不定义
;;; 伪寄存器，所以跨调用的值仍然 live。

(require "../../compiler/analyze/analyze.rkt"
         "uses.rkt"
         "pseudo.rkt")

(provide (struct-out liveness)
         compute-liveness
         block-live-in
         block-live-out
         live-out-after)

;; live-ins / live-outs : vector，每个块一个下标列表
;; live-out-after       : vector of vector，每个块里每条 item 之后的下标列表
;; pseudos              : 排序后的伪寄存器下标表
(struct liveness (live-ins live-outs live-out-after pseudos) #:transparent)

(define (union* sets)
  (sort (remove-duplicates (append* sets)) <))

(define (set-minus a b)
  (for/list ([x (in-list a)] #:unless (memv x b)) x))

(define (set-union a b)
  (union* (list a b)))

(define (compute-liveness program-or-items)
  (define prog (if (program? program-or-items)
                   program-or-items
                   (analyze program-or-items)))
  (define blocks (list->vector (program-blocks prog)))
  (define flows (list->vector (program-flows prog)))
  (define n (vector-length blocks))
  (define live-ins (make-vector n '()))
  (define live-outs (make-vector n '()))
  (define live-out-after
    (for/vector ([block (in-vector blocks)])
      (make-vector (length (block-items block)) '())))

  (define (successors i)
    (flow-succ (vector-ref flows i)))

  (let loop ()
    (define changed? #f)
    (for ([i (in-range n)])
      (define block (vector-ref blocks i))
      (define items (block-items block))
      (define out (union* (for/list ([s (in-list (successors i))])
                            (vector-ref live-ins s))))
      (define live out)
      (for ([j (in-range (sub1 (vector-length (vector-ref live-out-after i))) -1 -1)])
        (define item (list-ref items j))
        (define-values (uses defs) (instruction-uses/sets item))
        (vector-set! (vector-ref live-out-after i) j live)
        (set! live (set-union uses (set-minus live defs))))
      (define in live)
      (unless (equal? out (vector-ref live-outs i))
        (set! changed? #t)
        (vector-set! live-outs i out))
      (unless (equal? in (vector-ref live-ins i))
        (set! changed? #t)
        (vector-set! live-ins i in)))
    (when changed? (loop)))

  (define pseudos
    (sort (remove-duplicates
           (append* (for/list ([block (in-vector blocks)])
                      (append* (for/list ([item (in-list (block-items block))])
                                 (pseudo-registers-in item))))))
          <))
  (liveness live-ins live-outs live-out-after pseudos))

(define (block-live-in lv i) (vector-ref (liveness-live-ins lv) i))
(define (block-live-out lv i) (vector-ref (liveness-live-outs lv) i))

(define (live-out-after lv block-index item-index)
  (vector-ref (vector-ref (liveness-live-out-after lv) block-index) item-index))
