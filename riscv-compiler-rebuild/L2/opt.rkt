#lang racket
;;; L2/opt.rkt
;;;
;;; 在 CFG 上做优化。每个 pass 都是 (items ctx -> items), 只按块做局部改动。
;;;
;; 程序体允许整体多包一层 (begin form ...) 当容器: 进来剥掉、出去补上,
;;; 这样 L1 的 '(begin ...) 直接喂进来不会被当成一条叫 begin 的指令。
;;
;;; 段(segment): 屏障((section ...) / 数据 ...)把程序切成若干段。
;;; 屏障不跨: 每段单独建图、单独优化, 屏障本身原样保留。
;;; 跨段只会通过 label 引用发生, 所以可达性分析的根要包含
;;; "在本段之外被引用的 label"(见 program-context)。
;;;
;;; 现有 pass:
;;;   drop-unreachable            删掉走不到的块(连它的 label 一起删)
;;;   drop-transfers-to-next-block 删掉"跳到紧邻下一块"的跳转/分支 -> 落下去
;;;
;;; 不做的: 不重排指令、不跨屏障搬代码、不动不认识的指令。

(require "insn.rkt"
         "cfg.rkt")

(provide (struct-out segment)
         split-into-segments
         (struct-out program-context)
         make-context
         passes
         pass-names
         optimize-segment
         program-parts
         program-body
         optimize-program)

;; 一段连续可分析的代码
(struct segment (items) #:transparent)

;; 整程序的上下文: 跨段被引用的 label + 是否存在间接跳转
(struct program-context (referenced indirect?) #:transparent)

(define (make-context items)
  (program-context (referenced-labels items)
                   (for/or ([it (in-list items)])
                     (indirect-instruction? it))))

;; ---------------------------------------------------------------------------
;; 程序 <-> 段
;; ---------------------------------------------------------------------------

;; (quote (begin form ...)) -> 剥成 form 列表; 返回 (values items 容器?)
(define (quote-list? x)
  (and (form? x)
       (eq? (car x) 'quote)
       (pair? (cdr x))
       (null? (cddr x))
       (list? (cadr x))))

(define (begin-container? x)
  (and (form? x) (eq? (car x) 'begin)))

(define (program-body prog)
  (cond
    [(quote-list? prog) (cadr prog)]
    [(list? prog) prog]
    [else (list prog)]))

(define (program-parts prog)
  (define body (program-body prog))
  (cond
    [(begin-container? body) (values (cdr body) #t)]
    [else (values body #f)]))

(define (wrap-program items with-begin?)
  (list 'quote (if with-begin? (cons 'begin items) items)))

;; 按屏障切段; 屏障本身留在结果里占位
(define (split-into-segments items)
  (define out '())
  (define cur '())
  (define (flush!)
    (unless (null? cur)
      (set! out (cons (segment (reverse cur)) out))
      (set! cur '())))
  (for ([it (in-list items)])
    (cond
      [(barrier-form? it) (flush!) (set! out (cons it out))]
      [else (set! cur (cons it cur))]))
  (flush!)
  (reverse out))

;; ---------------------------------------------------------------------------
;; pass 1: 删不可达块
;;
;; 根 = 本段第一块
;;    + 名字在段外被引用的块(例如上一段 jal 过来)
;;    + 存在 jalr 时, 所有有名字的块(间接跳转可能落到任何 label)
;; 走不到的块连同它的 label 一起删: 既然 walk 不到, 它的 label 也就没被引用。
;; ---------------------------------------------------------------------------

(define (drop-unreachable items ctx)
  (define g (build-cfg items))
  (define blocks (graph-blocks g))
  (cond
    [(zero? (vector-length blocks)) items]
    [else
     (define referenced (program-context-referenced ctx))
     (define indirect? (program-context-indirect? ctx))
     (define roots
       (for/list ([b (in-vector blocks)] [i (in-naturals)]
                  #:when (or (zero? i)
                             (and (pair? (block-labels b))
                                  (or indirect?
                                      (ormap (lambda (l) (memq l referenced))
                                             (block-labels b))))))
         i))
     (define keep (cfg-reachable g roots))
     (cond
       [(= (length keep) (vector-length blocks)) items]
       [else (append* (for/list ([i (in-list keep)])
                        (block->items (vector-ref blocks i))))])]))

;; 块 -> 线性指令
(define (block->items b)
  (append (for/list ([l (in-list (block-labels b))]) (list 'label l))
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
              (memq (jump-target last-insn) (block-labels next)))
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

(define (optimize-segment items ctx)
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

;; 全程序: 切段 -> 逐段优化 -> 按原顺序拼回 -> 包回 quote-list
(define (optimize-program prog)
  (define-values (items with-begin?) (program-parts prog))
  (define ctx (make-context items))
  (define optimized
    (for/list ([piece (in-list (split-into-segments items))])
      (cond
        [(segment? piece) (optimize-segment (segment-items piece) ctx)]
        [else (list piece)])))
  (wrap-program (append* optimized) with-begin?))
