#lang racket
;;; L3/cfg.rkt
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
;;; 边: 块的最后一条指令决定后继(压缩形式 c.j/c.jal/c.jr/c.jalr/c.beqz/c.bnez
;;; 与对应展开形式同规则)
;;;   分支        目标块 + 下一块
;;;   jal x0      目标块
;;;   jal ra      目标块 + 下一块(返回地址 = pc+4)
;;;   jalr x0     无(不回来)
;;;   jalr ra     下一块(返回地址 = pc+4; 目标不可知, 记 indirect?)
;;;   ecall       下一块(返回地址 = pc+4)
;;;   ebreak      无
;;;   其他        下一块
;;;
;;; 目标 label 不存在时不加边(交给布局层报 undefined-target)。

(require "insn.rkt")

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
  (define targets (referenced-labels items))     ; 控制转移的目标链
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
         [(member path targets) (flush!) (set! cur-labels (list path))]
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
               [(branch-instruction? last-insn)
                (succs (edge (jump-target last-insn)) fallthrough)]
               [(jump-instruction? last-insn)
                (succs (edge (jump-target last-insn))
                       (and (falls-through? last-insn) fallthrough))]
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
              #:when (or (branch-instruction? it) (jump-instruction? it))
              #:do [(define p (normalize-path (jump-target it)))]
              #:when p)
     p)))

;; 被当成"值"用过的链(不是控制转移目标的引用), 例如 (la t0 (b)) / (ld t0 (table))。
;; 间接跳转的目标只能来自"取过地址"的链, 所以它们是有间接跳转时的候选落点。
;; 数据侧也算: (value 宽度 (label+ 链 加数)) 把链的地址写进了数据(函数表/跳转表),
;; 所以 L3 也要吃数据 item —— 见 analyze 的第二个参数。
(define (value-ref it)
  (and (form? it)
       (eq? (car it) 'value)
       (= 3 (length it))
       (let ([v (caddr it)])
         (and (form? v) (eq? (car v) 'label+) (= 3 (length v))
              (path? (cadr v))
              (cadr v)))))

(define (address-taken-paths items)
  (remove-duplicates
   (append*
    (for/list ([it (in-list items)] #:when (form? it))
      (define operands
        (if (or (branch-instruction? it) (jump-instruction? it))
            (drop-right (cdr it) 1)      ; 最后一个操作数是跳转目标, 不算取值
            (cdr it)))
      (define refs (filter path? operands))
      (if (value-ref it) (cons (value-ref it) refs) refs)))))

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
