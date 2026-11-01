#lang racket
;;; analyze/cfg.rkt
;;;
;;; 线性指令 -> 基本块图。
;;;
;;; 切块规则(leader):
;;;   - 程序开头
;;;   - 控制转移的目标 label
;;;   - 每条 ends-block? 指令之后
;;; 连续的多个 (label ...) 归同一个块(块可以有多名字); 不是目标的 label
;;; 不切块, 作为位置标记留在块里。
;;;
;;; 边: 块的最后一条指令决定后继
;;;   jcc-*         目标块 + 下一块
;;;   jmp-*         目标块
;;;   call-*        目标块 + 下一块(调用会返回)
;;;   jmp-indirect  无顺序边
;;;   call-indirect 下一块
;;;   ret/ud2/hlt   无
;;;   其他          下一块
;;;
;;; 目标 label 不存在时不加边(交给布局层报 undefined-target)。

(require "../../amd64-asm/sexp.rkt"
         "insn.rkt")

(provide (struct-out basic-block)
         (struct-out graph)
         build-cfg
         cfg-block-count
         cfg-reachable
         cfg->lines
         referenced-labels
         address-taken-paths)

;; 一个基本块: 头部的若干 label + 程序 item + 后继(块下标)
(struct basic-block (labels items successors) #:transparent)

;; 一张图: 块向量 + 有没有间接跳转
(struct graph (blocks indirect?) #:transparent)

;; ---------------------------------------------------------------------------
;; 建图
;; ---------------------------------------------------------------------------

(define (build-cfg items)
  ;; 1. 切块: 先收集 (labels . insns) 的逆序
  ;; 目标链做成哈希集合: 下面是"每个 label 查一次", 用 (member …) 在
  ;; 大镜像(几十万 label / 几万目标)上是二次的。
  (define targets
    (for/hash ([p (in-list (referenced-labels items))]) (values p #t)))
  (define collected '())
  (define cur-labels '())
  (define cur-insns '())

  (define (flush!)
    (when (or (pair? cur-labels) (pair? cur-insns))
      (set! collected
            (cons (cons (reverse cur-labels) (reverse cur-insns)) collected))
      (set! cur-labels '())
      (set! cur-insns '())))

  (for ([it (in-list items)])
    (cond
      [(label-form? it)
       (define path (label-path it))
       (cond
         ;; 块开头(还没放 item): 归块头的多个名字
         [(null? cur-insns) (set! cur-labels (cons path cur-labels))]
         ;; 目标是 leader: 另起一块
         [(hash-ref targets path #f) (flush!) (set! cur-labels (list path))]
         ;; 非目标 label: 位置标记, 留在块里
         [else (set! cur-insns (cons it cur-insns))])]
      [else
       (set! cur-insns (cons it cur-insns))
       (when (ends-block? it) (flush!))]))

  (flush!)
  (define raw (reverse collected))

  ;; 2. 链 -> 块下标(目标一定在块头, 所以只登记块头)
  (define label->index (make-hash))
  (for ([entry (in-list raw)] [i (in-naturals)])
    (for ([p (in-list (car entry))])
      (hash-set! label->index p i)))

  ;; 3. 算每个块的后继(顺序边只在真的会落到下一条时才有)
  (define n (length raw))
  (define blocks
    (for/vector ([entry (in-list raw)] [i (in-naturals)])
      (define insns (cdr entry))
      (define last-insn (and (pair? insns) (last insns)))
      (define fallthrough (and (< (add1 i) n) (add1 i)))
      (define (edge target)
        (define p (normalize-path target))
        (and p (hash-ref label->index p #f)))
      (define (succs . xs) (remove-duplicates (filter values xs)))
      (basic-block (car entry)
                   insns
                   (cond
               [(or (branch-instruction? last-insn)
                    (call-instruction? last-insn))
                (succs (edge (jump-target last-insn)) fallthrough)]
               [(jump-instruction? last-insn)
                (succs (edge (jump-target last-insn)))]
               [(or (indirect-instruction? last-insn) (trap-instruction? last-insn))
                (succs (and (falls-through? last-insn) fallthrough))]
               [else (succs fallthrough)]))))

  (graph blocks
         (for/or ([it (in-list items)])
           (indirect-instruction? it))))

(define (cfg-block-count g) (vector-length (graph-blocks g)))

;; ---------------------------------------------------------------------------
;; 分析
;; ---------------------------------------------------------------------------

;; 整段代码里被当成跳转/分支目标出现过的链(含跨段的)
(define (referenced-labels items)
  (remove-duplicates
   (for/list ([it (in-list items)]
              #:when (or (branch-instruction? it)
                         (jump-instruction? it)
                         (call-instruction? it))
              #:do [(define p (normalize-path (jump-target it)))]
              #:when p)
     p)))

;; 被当成"值"用过的链(不是控制转移目标的引用), 例如 (la t0 (b)) / (ld t0 (table))。
;; 间接跳转的目标只能来自"取过地址"的链, 所以它们是有间接跳转时的候选落点。
;; 数据侧也算（analyze 的第二个参数就是 data items）。什么算"取过地址":
;;   (la rd [tmp] 地址表达式)     表达式里的所有链
;;   (value 宽度 地址表达式)       数据里的所有链（差值也算: 那两个 label 必须存在）
;;   其它指令:                              操作数里出现的裸链
(define (operand-address-chains op)
  (cond
    [(mem-form? op) (address-expr-chains (mem-disp (parse-mem op)))]
    [(address-expr? op) (address-expr-chains op)]
    [(form? op) (append* (for/list ([x (in-list (cdr op))])
                           (operand-address-chains x)))]
    [else '()]))

(define (item-address-chains it)
  (cond
    [(eq? (car it) 'value) (address-expr-chains (caddr it))]
    [(or (branch-instruction? it)
         (jump-instruction? it)
         (call-instruction? it))
     (append* (for/list ([op (in-list (drop-right (cdr it) 1))])
                (operand-address-chains op)))]
    [else (append* (for/list ([op (in-list (cdr it))])
                     (operand-address-chains op)))]))

(define (address-taken-paths items)
  (remove-duplicates
   (append* (for/list ([it (in-list items)] #:when (form? it))
              (item-address-chains it)))))

;; 从 roots 出发能走到的块下标(升序)
(define (cfg-reachable g roots)
  (define blocks (graph-blocks g))
  (define seen (make-vector (vector-length blocks) #f))
  (define (visit! i)
    (unless (vector-ref seen i)
      (vector-set! seen i #t)
      (for ([s (in-list (basic-block-successors (vector-ref blocks i)))])
        (visit! s))))
  (for ([r (in-list roots)])
    (when (< r (vector-length blocks)) (visit! r)))
  (for/list ([i (in-range (vector-length blocks))]
             #:when (vector-ref seen i))
    i))

;; 给人看的图: 一行一个块
(define (cfg->lines g)
  (for/list ([b (in-vector (graph-blocks g))] [i (in-naturals)])
    (format "b~a labels=~s insns=~a succs=~s"
            i (basic-block-labels b) (length (basic-block-items b)) (basic-block-successors b))))
