#lang racket
;;; L3/opt.rkt
;;;
;;; 在 CFG 上做优化。每个 pass 都是 (items ctx -> items), 只按块做局部改动。
;;;
;;; 程序是普通 list: '((item) (item) ...)
;;;
;;; 整段程序一张 CFG。输出是**块列表**, 把控制流分析结果交给 L4:
;;;
;;;   (block (id 0) (labels ((prog1 main))) (insns ((lwu ...) ...))
;;;          (succ (1 3)) (fallthrough 1))
;;;
;;;   id          块身份
;;;   labels      块头的所有链(一个位置多名也在这里); 放置规则只认它
;;;   insns       块内容
;;;   succ        后继块 id
;;;   fallthrough 顺序落到哪个块; #f = 不以顺序方式离开
;;;
;;; 这样 L4 不需要重新分析控制流, 也能检查"搬动块会不会剪断顺序执行"。
;;;
;;; 现有 pass:
;;;   drop-unreachable            删掉走不到的块(连它的 label 一起删)
;;;   drop-transfers-to-next-block 删掉"跳到紧邻下一块"的跳转/分支 -> 落下去
;;;
;;; 不做的: 不重排指令、不跨屏障搬代码、不动不认识的指令。

(require "insn.rkt"
         "cfg.rkt")

(provide (struct-out program-context)
         make-context
         passes
         pass-names
         optimize-items
         program-items
         optimize-program)

;; 整程序的上下文: 被引用的链 + 地址被取过的链 + 是否存在间接跳转
(struct program-context (referenced address-taken indirect?) #:transparent)

(define (make-context items)
  (program-context (referenced-labels items)
                   (address-taken-paths items)
                   (for/or ([it (in-list items)])
                     (indirect-instruction? it))))

;; ---------------------------------------------------------------------------
;; 程序 <-> 段
;; ---------------------------------------------------------------------------

;; 程序 = 普通 list; 旧壳 (quote ...) / (begin ...) 也收
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
      [(pair? (car body)) body]        ; 头是 list -> item 列表
      [else (list body)]))             ; 单条 item
  (if (and (form? (car items)) (eq? (caar items) 'begin) (= 1 (length items)))
      (cdar items)
      items))

;; ---------------------------------------------------------------------------
;; pass 1: 删不可达块
;;
;; 根 = 入口块(第一块)
;;    + 名字被直接引用的块(jal/分支的目标)
;;    + 存在 jalr 时, 名字"被取过地址"的块(间接跳转只可能落到这种地方)
;; 走不到的块连同它的 label 一起删: 既然 walk 不到, 它的 label 也就没被引用。
;; ---------------------------------------------------------------------------

(define (drop-unreachable items ctx)
  (define g (build-cfg items))
  (define blocks (graph-blocks g))
  (cond
    [(zero? (vector-length blocks)) items]
    [else
     (define roots-of-interest
       (if (program-context-indirect? ctx)
           (append (program-context-referenced ctx)
                   (program-context-address-taken ctx))
           (program-context-referenced ctx)))
     (define roots
       (for/list ([b (in-vector blocks)] [i (in-naturals)]
                  #:when (or (zero? i)
                             (ormap (lambda (p) (member p roots-of-interest))
                                    (block-labels b))))
         i))
     (define keep (cfg-reachable g roots))
     (cond
       [(= (length keep) (vector-length blocks)) items]
       [else (append* (for/list ([i (in-list keep)])
                        (block->items (vector-ref blocks i))))])]))

;; 块 -> 线性指令: 每条链写回一条 (label . 链)
(define (block->items b)
  (append (for/list ([p (in-list (block-labels b))]) (cons 'label p))
          (block-insns b)))

;; ---------------------------------------------------------------------------
;; pass 2: 转移到紧邻下一块 -> 删掉, 直接落下去
;;
;;   (jal x0 L) / (beq a b L) 后面紧挨着 (label L) 时, 两种走向本来就一样,
;;   控制转移是多余的。
;; ---------------------------------------------------------------------------

(define (drop-transfers-to-next-block items ctx)
  (define g (build-cfg items))
  (define blocks (graph-blocks g))
  (define changed? #f)
  (define out
    (for/list ([b (in-vector blocks)] [i (in-naturals)])
      (define next (and (< (add1 i) (vector-length blocks))
                        (vector-ref blocks (add1 i))))
      (define insns (block-insns b))
      (define last-insn (and (pair? insns) (last insns)))
      (cond
        [(and next
              (or (unconditional-jump? last-insn)
                  (branch-instruction? last-insn))
              (member (normalize-path (jump-target last-insn))
                      (block-labels next)))
         (set! changed? #t)
         (block (block-labels b) (drop-right insns 1) (block-successors b))]
        [else b])))
  (if changed?
      (append* (for/list ([b (in-list out)]) (block->items b)))
      items))

;; ---------------------------------------------------------------------------
;; pass 表 + 跑法
;; ---------------------------------------------------------------------------

(define passes
  (list (cons 'drop-unreachable              drop-unreachable)
        (cons 'drop-transfers-to-next-block  drop-transfers-to-next-block)))

;; 每段的 pass 名字(给 demo / 调试)
(define (pass-names) (map car passes))

;; 反复跑到不再变化; 轮数有上限, 防止 pass 之间来回抖
(define max-rounds 16)

(define (optimize-items items ctx)
  (let loop ([items items] [round 0])
    (cond
      [(>= round max-rounds) items]
      [else
       (define next
         (for/fold ([acc items]) ([p (in-list passes)])
           ((cdr p) acc ctx)))
       (if (equal? next items)
           items
           (loop next (add1 round)))])))

;; 全程序: 优化到不动点 -> 按最终 CFG 输出块列表
(define (optimize-program prog)
  (define items (program-items prog))
  (define ctx (make-context items))
  (blocks->sexp (optimize-items items ctx)))

;; 一张图 -> 块列表(交给 L4)
(define (blocks->sexp items)
  (define g (build-cfg items))
  (define blocks (graph-blocks g))
  (define n (vector-length blocks))
  (for/list ([b (in-vector blocks)] [i (in-naturals)])
    (define succ (block-successors b))
    (define next (and (< (add1 i) n) (add1 i)))
    (define fallthrough (and next (memv next succ) next))
    (list 'block
          (list 'id i)
          (cons 'labels (block-labels b))
          (cons 'insns (block-insns b))
          (cons 'succ succ)
          (list 'fallthrough (or fallthrough #f)))))
