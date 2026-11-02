#lang racket
;;; dce/dce.rkt
;;;
;;; 死代码消除(会改控制流): program -> program
;;;
;;; program 来自 analyze, 由两份平行数据组成:
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

(require "../../amd64-asm/sexp.rkt"
         "../analyze/analyze.rkt"
         "../analyze/insn.rkt")

(provide passes
         pass-names
         optimize-program
         eliminate-dead)

;; ---------------------------------------------------------------------------
;; 组装: 保持 blocks/flows 对齐并重新编号
;; ---------------------------------------------------------------------------

;; kept : (listof (list 旧 id 块 流))
(define (rebuild-program kept)
  (define new-of (make-hash))
  (for ([e (in-list kept)] [new (in-naturals)])
    (hash-set! new-of (car e) new))
  (define (map-id id)
    (hash-ref new-of id #f))
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

;; 注意 (list-ref entries i): 在可达性遍历里对每个块取一次就是 O(块数),
;; 整体二次。先转 vector。
(define (drop-unreachable prog)
  (define entries (list->vector (zip-program prog)))
  (define n (vector-length entries))
  (define seen (make-vector n #f))
  (define (visit! i)
    (unless (vector-ref seen i)
      (vector-set! seen i #t)
      (for ([s (in-list (flow-succ (caddr (vector-ref entries i))))])
        (when (< s n) (visit! s)))))
  (for ([e (in-vector entries)] #:when (flow-root? (caddr e)))
    (visit! (car e)))
  (check-deletion-evidence! entries seen)
  (define kept (for/list ([e (in-vector entries)] #:when (vector-ref seen (car e))) e))
  (if (= (length kept) n) prog (rebuild-program kept)))

;; 删一个块之前, 要能说出"它为什么不可达"。
;;
;; 删代码时愿意接受的"不落下"依据。**这是和 amd64-asm 的 flow 事实独立的
;; 一张表**: 那边说"这条 form 不落下"(事实), 这边说"我愿意据此删代码"(政策)。
;;   'jump / 'jump-indirect  目标是我们自己摆的转移形式, 后面的代码只能靠
;;                           label/其它边到达 —— 可以据删。
;;   'stop                   只有硬件保证的那两条(ret/ud2); 表里新增一个
;;                           'stop 的 form 不会自动获得删代码的许可。
(define (accepted-deletion-evidence? reason last-item)
  (case reason
    [(jump jump-indirect) #t]
    [(stop) (and (form? last-item) (memq (car last-item) '(ret ud2)))]
    [else #f]))

(define (last-block-item block)
  (define items (block-items block))
  (and (pair? items) (last items)))

;; 程序顺序就是物理顺序, 所以被判死的块的**前一块**就是那道闸门: 前一块要是
;; 顺序落下, 这块本来就在它的顺序边上, 不会被判死。于是每个被删的块都该能回答
;; "前一块为什么不落下"; 而"不落下"这件事只能有两个来源:
;;   1. 我们自己生成的转移形式(jump / jmp-indirect);
;;   2. 硬件保证不继续的 form(special 表里标 'stop 的, 只有 ret / ud2 ——
;;      曾经把 hlt 写进这一类, 后果是删掉了 syscall-hlt 的队尾)。
;; 这里用 (non-fallthrough-reason …) **重算**一遍, 而不是相信 flow 里的
;; fallthrough 字段; 而且只接受下面这四种依据 —— 这是**和 insn.rkt 名单
;; 独立的第二张表**: 那边回答"这条指令凭什么不落下", 这边回答"删代码时我
;; 愿意接受哪几种依据"。想给某条指令加"不落下", 两边都得改, 而且改这边时必须
;; 先想清楚"删掉后面的代码会不会出事"。换句话说, 删代码这个动作自己看得懂依据,
;; 不继承上游一个布尔值。
(define (check-deletion-evidence! entries seen)
  (define n (vector-length entries))
  (for ([e (in-vector entries) ] [i (in-naturals)])
    (unless (vector-ref seen i)
      ;; 往前找最近的一个活着的块: 它就是物理上的前一块
      (define prev
        (for/first ([j (in-range (sub1 i) -1 -1)] #:when (vector-ref seen j)) j))
      (when prev
        (define prev-flow (caddr (vector-ref entries prev)))
        (define prev-block (cadr (vector-ref entries prev)))
        (define last-item (last-block-item prev-block))
        (unless (flow-fallthrough prev-flow)
          ;; flow 说前一块不顺序落下, 那就必须有 dce 认得的依据
          (define reason (and last-item (non-fallthrough-reason last-item)))
          (unless (and reason (accepted-deletion-evidence? reason last-item))
            (error 'dce
                   (string-append
                    "块 ~a 因为没有顺序边被判死, 但前一块(块 ~a)的末条 item ~e "
                    "给出的\"不落下\"依据是 ~e。\n"
                    "  dce 只接受 jump/jump-indirect, 以及 stop 里的 (ret ud2)。\n"
                    "  想加新的依据: 先证明它真的不会继续执行, 再改"
                    " amd64-asm/special 表的 flow 和这里的 accepted-deletion-evidence?。\n"
                    "  拒绝删除 —— 否则会把还会执行的代码丢掉(参见 hlt 那次)。")
                   (car e) prev (and last-item (list last-item)) reason))))))
  (void))

;; ---------------------------------------------------------------------------
;; pass 2: 转移到紧邻下一块 -> 删掉, 直接落下去
;; ---------------------------------------------------------------------------

(define (transfer-to-next? block next-block)
  (define last-insn (last-block-item block))
  (and next-block
       (or (unconditional-jump? last-insn)
           (branch-instruction? last-insn))
       (member (normalize-path (jump-target last-insn)) (block-head next-block))))

;; 注意: 下面用 vector 而不是 (list-ref blocks (add1 i)) —— 后者在循环里
;; 是 O(块数) 的, 整个 pass 就变成二次的(pc-repl 有十万级基本块)。
(define (drop-transfers-to-next-block prog)
  (define blocks (list->vector (program-blocks prog)))
  (define flows (program-flows prog))
  (define n-blocks (vector-length blocks))
  (define changed (make-vector n-blocks #f))
  (define new-blocks
    (for/list ([b (in-vector blocks)] [i (in-naturals)])
      (define next (and (< (add1 i) n-blocks) (vector-ref blocks (add1 i))))
      (cond
        [(transfer-to-next? b next)
         (vector-set! changed i #t)
         (make-block (block-head b) (drop-right (block-items b) 1))]
        [else b])))
  (if (not (ormap values (vector->list changed)))
      prog
      (let ([n-new (length new-blocks)])   ; 别在循环里算: 那是 O(块数) 的
        (rebuild-program
         (for/list ([b (in-list new-blocks)] [f (in-list flows)] [i (in-naturals)])
           (cond
             ;; 删掉转移后只剩顺序边
             [(vector-ref changed i)
              (define next (and (< (add1 i) n-new) (add1 i)))
              (list i b (make-flow (if next (list next) '()) next (flow-root? f)))]
             ;; 没动的块: 流原样交给 rebuild-program 重映射
             [else (list i b f)]))))))

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
      (rebuild-program
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
