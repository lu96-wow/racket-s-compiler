#lang racket
;;; L4/dce.rkt
;;;
;;; 死代码消除(会改控制流): block list -> block list
;;;
;;; 输入/输出都是 L3 的块列表(Racket struct), 不是 s-exp。
;;;
;;; 本层做的两件事:
;;;   drop-unreachable             从 root? 块出发走不到的一律删掉(连 label)
;;;   drop-transfers-to-next-block 删掉"跳到紧邻下一块"的转移 -> 变成顺序落下
;;;
;;; 两者都会改变 succ / fallthrough, 所以每次改完都重算:
;;;   - 删块后重新编号 id, 重映射 succ / fallthrough
;;;   - 删转移后该块只剩顺序边: succ = (下一个块), fallthrough = 下一个块
;;;
;;; 不做的: 不重排块、不动指令、不认识 label 之外的东西(分析信息全在 block 里)。

(require "../L3/analyze.rkt"
         "../L3/insn.rkt")

(provide passes
         pass-names
         optimize-blocks
         eliminate-dead)

;; ---------------------------------------------------------------------------
;; 工具
;; ---------------------------------------------------------------------------

(define (next-block blocks i)
  (and (< (add1 i) (length blocks)) (list-ref blocks (add1 i))))

;; 重新编号: 保持顺序, id 变 0..n-1, succ/fallthrough 跟着改
(define (reindex blocks)
  (define new-id (make-hash))
  (for ([b (in-list blocks)] [i (in-naturals)])
    (hash-set! new-id (block-id b) i))
  (for/list ([b (in-list blocks)] [i (in-naturals)])
    (define ft (block-fallthrough b))
    (block i
           (block-labels b)
           (block-insns b)
           (for/list ([s (in-list (block-succ b))]
                      #:when (hash-ref new-id s #f))
             (hash-ref new-id s))
           (cond
             [(not ft) #f]
             [(not (hash-ref new-id ft #f))
              ;; 顺序后继不可能不可达(否则它就被那条边走到了), 这里只是兜底
              (error 'reindex "fallthrough target ~a disappeared" ft)]
             [else (hash-ref new-id ft)])
           (block-root? b))))

;; ---------------------------------------------------------------------------
;; pass 1: 删不可达块
;; ---------------------------------------------------------------------------

(define (drop-unreachable blocks)
  (define by-id (for/hash ([b (in-list blocks)]) (values (block-id b) b)))
  (define seen (make-hash))
  (define (visit! id)
    (unless (hash-ref seen id #f)
      (hash-set! seen id #t)
      (for ([s (in-list (block-succ (hash-ref by-id id)))])
        (when (hash-ref by-id s #f) (visit! s)))))
  (for ([b (in-list blocks)] #:when (block-root? b))
    (visit! (block-id b)))
  (define kept (for/list ([b (in-list blocks)]
                          #:when (hash-ref seen (block-id b) #f))
                 b))
  (if (= (length kept) (length blocks)) blocks (reindex kept)))

;; ---------------------------------------------------------------------------
;; pass 2: 转移到紧邻下一块 -> 删掉, 直接落下去
;; ---------------------------------------------------------------------------

(define (transfer-to-next? b next)
  (define insns (block-insns b))
  (define last-insn (and (pair? insns) (last insns)))
  (and next
       (or (unconditional-jump? last-insn)
           (branch-instruction? last-insn))
       (member (normalize-path (jump-target last-insn)) (block-labels next))))

(define (drop-transfers-to-next-block blocks)
  (define changed? #f)
  (define out
    (for/list ([b (in-list blocks)] [i (in-naturals)])
      (define next (next-block blocks i))
      (cond
        [(transfer-to-next? b next)
         (set! changed? #t)
         (block (block-id b)
                (block-labels b)
                (drop-right (block-insns b) 1)
                (list (block-id next))
                (block-id next)
                (block-root? b))]
        [else b])))
  (if changed? out blocks))

;; ---------------------------------------------------------------------------
;; pass 表 + 跑法
;; ---------------------------------------------------------------------------

(define passes
  (list (cons 'drop-unreachable              drop-unreachable)
        (cons 'drop-transfers-to-next-block  drop-transfers-to-next-block)))

(define (pass-names) (map car passes))

;; 反复跑到不再变化; 轮数有上限, 防止 pass 之间来回抖
(define max-rounds 16)

(define (optimize-blocks blocks)
  (let loop ([blocks blocks] [round 0])
    (cond
      [(>= round max-rounds) blocks]
      [else
       (define next
         (for/fold ([acc blocks]) ([p (in-list passes)])
           ((cdr p) acc)))
       (if (equal? next blocks) blocks (loop next (add1 round)))])))

;; 本层主入口
(define (eliminate-dead blocks) (optimize-blocks blocks))
