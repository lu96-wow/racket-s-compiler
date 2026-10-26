#lang racket
;;; L3/analyze.rkt
;;;
;;; 控制流分析: 只分析, 不改程序。
;;;
;;;   (analyze items) -> program
;;;
;;; 程序被切成**块**, 每块两部分:
;;;
;;;   (block <头 label 链列表> item ...)
;;;
;;;   - 头: 该块开头的 label 链(可能为空表 = 没有 label 的块)。这就是块的身份。
;;;   - 程序: 该块的 item, 纯 s-exp; 块内的位置标记 label 也在里面。
;;;
;;; 只想要"程序"的层直接 (cddr block) 即可, 不需要认识别的。
;;;
;;; 控制流信息**不在块里**, 单独一份, 与块列表一一对应:
;;;
;;;   (flow (succ <块下标> ...) (fallthrough <块下标>|#f) (root? <bool>))
;;;
;;;   succ        后继块下标
;;;   fallthrough 物理下一条是哪个块; #f = 不以顺序方式离开
;;;   root?       外部入口: 程序入口 / (有间接跳转时)地址被取过的块
;;;
;;; (struct program (blocks flows)) 把两份数据装在一起。
;;;
;;; 块边界只由控制流决定:
;;;   程序开头 / 控制转移的目标 label / ends-block? 指令之后。
;;; 非目标的 label 不是边界, 它作为位置标记留在块的程序里。

(require "insn.rkt"
         (prefix-in cfg: "cfg.rkt"))

(provide (struct-out program)
         analyze
         program-items
         block-head block-items make-block
         flow-succ flow-fallthrough flow-root? make-flow
         program->sexp sexp->program)

;; ---------------------------------------------------------------------------
;; 块 / 流
;; ---------------------------------------------------------------------------

;; 块 = (block (链 ...) item ...)
(define (block-head b) (cadr b))
(define (block-items b) (cddr b))
(define (make-block head items) (cons 'block (cons head items)))

;; 流 = (flow (succ id ...) (fallthrough id|#f) (root? bool))
(define (flow-succ f)        (cdr (assoc 'succ (cdr f))))
(define (flow-fallthrough f) (cadr (assoc 'fallthrough (cdr f))))
(define (flow-root? f)       (cadr (assoc 'root? (cdr f))))
(define (make-flow succ fallthrough root?)
  (list 'flow (cons 'succ succ) (list 'fallthrough fallthrough) (list 'root? root?)))

;; 程序 = 块列表 + 流列表(一一对应)
(struct program (blocks flows) #:transparent)

;; ---------------------------------------------------------------------------
;; 程序 -> item 列表(旧壳 quote/begin 也收)
;; ---------------------------------------------------------------------------

(define (program-items prog)
  (define body
    (cond
      [(and (form? prog) (eq? (car prog) 'quote) (= 2 (length prog)) (list? (cadr prog)))
       (cadr prog)]
      [(list? prog) prog]
      [else (list prog)]))
  (define items
    (cond
      [(null? body) '()]
      [(pair? (car body)) body]
      [else (list body)]))
  (if (and (= 1 (length items)) (form? (car items)) (eq? (caar items) 'begin))
      (cdar items)
      items))

;; ---------------------------------------------------------------------------
;; 分析
;; ---------------------------------------------------------------------------

(define (analyze program-or-items)
  (define items (program-items program-or-items))
  (define g (cfg:build-cfg items))
  (define cfg-blocks (cfg:graph-blocks g))
  (define n (vector-length cfg-blocks))

  ;; 根只有"外部入口": 入口块 + (有间接跳转时)地址被取过的块。
  ;; 内部引用不是根 —— 它们在 CFG 里就是边。
  (define address-taken (if (cfg:graph-indirect? g)
                            (cfg:address-taken-paths items)
                            '()))

  (define blocks
    (for/list ([b (in-vector cfg-blocks)])
      (make-block (cfg:basic-block-labels b) (cfg:basic-block-items b))))

  (define flows
    (for/list ([b (in-vector cfg-blocks)] [i (in-naturals)])
      (define succ (cfg:basic-block-successors b))
      (define next (and (< (add1 i) n) (add1 i)))
      (define fallthrough (and next (memv next succ) next))
      ;; 块里所有 label(块头 + 块内位置标记)
      (define all-labels
        (append (cfg:basic-block-labels b)
                (for/list ([it (in-list (cfg:basic-block-items b))] #:when (label-form? it))
                  (label-path it))))
      (define root? (or (zero? i)
                        (and (ormap (lambda (p) (member p address-taken)) all-labels) #t)))
      (make-flow succ (or fallthrough #f) root?)))

  (program blocks flows))

;; ---------------------------------------------------------------------------
;; 打印 / 读字面量
;; ---------------------------------------------------------------------------

;; 打印成 ((blocks …) (flows …)): 顶层就是字段表, 没有额外的标签壳。
(define (program->sexp prog)
  (list (cons 'blocks (program-blocks prog))
        (cons 'flows (program-flows prog))))

(define (sexp->program fields)
  (unless (and (list? fields) (andmap pair? fields))
    (error 'analyze "expected ((blocks ...) (flows ...)): ~e" fields))
  (define b (assoc 'blocks fields))
  (define f (assoc 'flows fields))
  (unless (and b f)
    (error 'analyze "expected ((blocks ...) (flows ...)): ~e" fields))
  (define blocks (cdr b))
  (define flows (cdr f))
  (unless (= (length blocks) (length flows))
    (error 'analyze "blocks and flows must have the same length"))
  (program blocks flows))
