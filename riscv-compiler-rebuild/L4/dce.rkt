#lang racket
;;; L4/dce.rkt
;;;
;;; 死代码消除(会改控制流): program -> program
;;;
;;; program 来自 L3, 由两份平行数据组成:
;;;   blocks : (block <头 label 链列表> item ...)
;;;   flows  : (flow (succ id ...) (fallthrough id|#f) (root? bool))
;;; 块的身份 = 它在 blocks 里的位置(0 起), succ/fallthrough 里的 id 就是这个位置。
;;;
;;; 三个 pass, 每个都同时改 blocks 和 flows:
;;;   drop-unreachable             从 root? 块走不到的一律删掉
;;;   drop-transfers-to-next-block 删掉"跳到紧邻下一块"的转移 -> 变成顺序落下
;;;   merge-empty-blocks           空块(没有 item)并进下一块(label 地址不变)
;;;
;;; 改完统一重新编号(位置即 id), succ/fallthrough 跟着重映射。

(require "../L3/analyze.rkt"
         "../L3/insn.rkt")

(provide passes
         pass-names
         optimize-program
         eliminate-dead)

;; ---------------------------------------------------------------------------
;; 组装: 保持 blocks/flows 对齐并重新编号
;; ---------------------------------------------------------------------------

;; kept : (listof (list 旧 id 块 流))
(define (assemble kept)
  (define new-of (make-hash))
  (for ([e (in-list kept)] [new (in-naturals)])
    (hash-set! new-of (car e) new))
  (define (map-id id)
    (and (hash-has-key? new-of id) (hash-ref new-of id)))
  (program
   (for/list ([e (in-list kept)]) (cadr e))
   (for/list ([e (in-list kept)])
     (define f (caddr e))
     (make-flow (filter values (for/list ([s (in-list (flow-succ f))]) (map-id s)))
                (and (flow-fallthrough f) (map-id (flow-fallthrough f)))
                (flow-root? f)))))

(define (zip-program prog)
  (for/list ([b (in-list (program-blocks prog))]
             [f (in-list (program-flows prog))]
             [i (in-naturals)])
    (list i b f)))

;; ---------------------------------------------------------------------------
;; pass 1: 删不可达块
;; ---------------------------------------------------------------------------

(define (drop-unreachable prog)
  (define entries (zip-program prog))
  (define n (length entries))
  (define seen (make-vector n #f))
  (define (visit! i)
    (unless (vector-ref seen i)
      (vector-set! seen i #t)
      (for ([s (in-list (flow-succ (caddr (list-ref entries i))))])
        (when (< s n) (visit! s)))))
  (for ([e (in-list entries)] #:when (flow-root? (caddr e)))
    (visit! (car e)))
  (define kept (for/list ([e (in-list entries)] #:when (vector-ref seen (car e))) e))
  (if (= (length kept) n) prog (assemble kept)))

;; ---------------------------------------------------------------------------
;; pass 2: 转移到紧邻下一块 -> 删掉, 直接落下去
;; ---------------------------------------------------------------------------

(define (last-item block) (and (pair? (block-items block)) (last (block-items block))))

(define (transfer-to-next? block next-block)
  (define last-insn (last-item block))
  (and next-block
       (or (unconditional-jump? last-insn)
           (branch-instruction? last-insn))
       (member (normalize-path (jump-target last-insn)) (block-head next-block))))

(define (drop-transfers-to-next-block prog)
  (define blocks (program-blocks prog))
  (define flows (program-flows prog))
  (define changed (make-vector (length blocks) #f))
  (define new-blocks
    (for/list ([b (in-list blocks)] [i (in-naturals)])
      (define next (and (< (add1 i) (length blocks)) (list-ref blocks (add1 i))))
      (cond
        [(transfer-to-next? b next)
         (vector-set! changed i #t)
         (make-block (block-head b) (drop-right (block-items b) 1))]
        [else b])))
  (if (not (ormap values (vector->list changed)))
      prog
      (assemble
       (for/list ([b (in-list new-blocks)] [f (in-list flows)] [i (in-naturals)])
         (cond
           ;; 删掉转移后只剩顺序边
           [(vector-ref changed i)
            (define next (and (< (add1 i) (length new-blocks)) (add1 i)))
            (list i b (make-flow (if next (list next) '()) next (flow-root? f)))]
           ;; 没动的块: 流原样交给 assemble 重映射
           [else (list i b f)])))))

;; ---------------------------------------------------------------------------
;; pass 3: 空块并进下一块
;; ---------------------------------------------------------------------------

(define (empty-block? b) (null? (block-items b)))

(define (merge-empty-blocks prog)
  (define pending '())            ; 逆序的空块 (list 旧 id 块 流)
  (define out '())
  (define redirect (make-hash))   ; 被并掉的旧 id -> 目标旧 id
  (define changed? #f)

  (for ([e (in-list (zip-program prog))])
    (define b (cadr e))
    (cond
      [(empty-block? b) (set! pending (cons e pending))]
      [else
       (when (pair? pending)
         (set! changed? #t)
         (for ([p (in-list pending)]) (hash-set! redirect (car p) (car e)))
         (define heads (append (append* (for/list ([p (in-list (reverse pending))])
                                          (block-head (cadr p))))
                               (block-head b)))
         (define root? (or (flow-root? (caddr e))
                           (ormap (lambda (p) (flow-root? (caddr p))) pending)))
         (set! b (make-block heads (block-items b)))
         (set! e (list (car e) b (make-flow (flow-succ (caddr e))
                                            (flow-fallthrough (caddr e))
                                            root?))))
       (set! out (cons e out))
       (set! pending '())]))
  ;; 末尾空块没有下一块可并
  (define all (append (reverse out) (reverse pending)))
  (if (not changed?)
      prog
      (assemble
       (for/list ([e (in-list all)])
         (define f (caddr e))
         (define (fix id) (hash-ref redirect id id))
         (list (car e)
               (cadr e)
               (make-flow (remove-duplicates (for/list ([x (in-list (flow-succ f))]) (fix x)))
                          (and (flow-fallthrough f) (fix (flow-fallthrough f)))
                          (flow-root? f)))))))

;; ---------------------------------------------------------------------------
;; pass 表 + 跑法
;; ---------------------------------------------------------------------------

(define passes
  (list (cons 'drop-unreachable              drop-unreachable)
        (cons 'drop-transfers-to-next-block  drop-transfers-to-next-block)
        (cons 'merge-empty-blocks            merge-empty-blocks)))

(define (pass-names) (map car passes))

(define max-rounds 16)

(define (optimize-program prog)
  (let loop ([prog prog] [round 0])
    (cond
      [(>= round max-rounds) prog]
      [else
       (define next (for/fold ([acc prog]) ([p (in-list passes)]) ((cdr p) acc)))
       (if (equal? next prog) prog (loop next (add1 round)))])))

;; 本层主入口
(define (eliminate-dead prog) (optimize-program prog))
