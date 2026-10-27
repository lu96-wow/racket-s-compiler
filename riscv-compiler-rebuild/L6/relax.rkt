#lang racket
;;; L6/relax.rkt
;;;
;;; 分支松弛: 把够不着的控制转移换成"更大一号"的形式, 直到全部够得着。
;;;
;;; 契约 (和 ARCHITECTURE 里 L6 的定义一致):
;;;   relax : program + data + layout 输入 -> layout
;;;   L5 的产物里没有块结构, 改完也没法重排, 所以本层**驱动** L5, 而不是吃 L5 的产物。
;;;
;;; 只做一件事: 把 needs-far 的 item 换成大一号的形式。
;;;
;;; 空槽(scratch-hole)**不填**: 那属于"动态内存布局 / 寄存器使用"那一层
;;; (还没实现)。本层把空槽原样留着, 让 L5 的 scratch-hole problem 作为交接点:
;;; 升到 branch-indirect / (jump-far x0 …) 时就会产生一个新的空槽。
;;;
;;; loop:
;;;   out  = L5(prog, data, layout)
;;;   edits = needs-far -> 换大一号 (far-step)
;;;   没有 edits -> 停
;;;   prog = apply-edits(prog, edits)
;;;
;;; 单调性 (为什么一定停):
;;;   每一次替换都让 item 变长 Δ > 0。对任意分支 (q -> t):
;;;     q,t 都在变长点同一侧  -> 距离不变
;;;     q,t 跨过变长点        -> |距离| 增加 Δ
;;;   所以"太远"的集合只增不减, 已经升级的不会再降级, 每个 item 最多升 3 档
;;;   (c.* -> 普通 -> 远形式 -> 间接), 轮数有上界。
;;;
;;; 本层**不造 label、不拆块、不改 CFG**: 远形式是定长 item, 由 L7 展开成
;;; "反向条件分支 + 紧接着的跳转"(和 gas 的 md_convert_frag_branch 同形)。
;;; 因此 place 行永远有效, fallthrough 也不会因为松弛而断。

(require (only-in "../L3/analyze.rkt" program program? program-blocks program-flows
                  block-head block-items make-block)
         (only-in "../L5/layout.rkt" layout-program layout-problems program-items)
         (only-in "../L5/forms.rkt" form?))

(provide relax
         far-step)

;; ---------------------------------------------------------------------------
;; 提升表: 超范围 -> 大一号。语义不变, 尺寸只增。
;; ---------------------------------------------------------------------------

(define (far-step it)
  (and (form? it)
       (case (car it)
         ;; 压缩 -> 普通(2 -> 4); 还远就下一轮继续升
         [(c.beqz) (list 'beq (cadr it) 'x0 (caddr it))]
         [(c.bnez) (list 'bne (cadr it) 'x0 (caddr it))]
         [(c.j)    (list 'jal 'x0 (cadr it))]
         [(c.jal)  (list 'jal 'ra (cadr it))]
         ;; b* -> 远分支(反向分支 + jal), 4 -> 8
         [(beq bne blt bge bltu bgeu)
          (list 'branch-far (car it) (cadr it) (caddr it) (cadddr it))]
         ;; 远分支 -> 间接远分支(反向分支 + auipc+jalr), 8 -> 12, 先留空槽
         [(branch-far)
          (list 'branch-indirect (cadr it) (caddr it) (cadddr it) (list-ref it 4))]
         ;; jal -> 远跳转, 4 -> 8
         ;;   (jal rd L) -> (jump-far rd L)      link 非零时它自己就是 base
         ;;   (jal L)    -> (jump-far ra L)     省略 rd 按 ra 算
         [(jal)
          (if (= 3 (length it))
              (list 'jump-far (cadr it) (caddr it))
              (list 'jump-far 'ra (cadr it)))]
         [else #f])))

;; ---------------------------------------------------------------------------
;; problems -> edits
;;   (needs-far 段 偏移 item 距离 (code 块 项))
;; 只有这一类能被本层改; scratch-hole 原样留着(见文件头)。
;; ---------------------------------------------------------------------------

;; 只有代码 item 能被本层改: (code 块 项) 是 L5 在 measure 时记下来的来源
(define (problem-origin p)
  (define tail (last p))
  (and (pair? tail) (eq? (car tail) 'code) tail))

(define (collect-edits problems)
  (append*
   (for/list ([p (in-list problems)]
              #:when (eq? (car p) 'needs-far))
     (define new (far-step (cadddr p)))
     (define o (problem-origin p))
     (if (and o new) (list (cons o new)) '()))))

;; ---------------------------------------------------------------------------
;; 把 edits 应用到 program(块 + 项 下标)
;; ---------------------------------------------------------------------------

(define (apply-edits prog edits)
  (define table (make-hash))
  (for ([e (in-list edits)]) (hash-set! table (car e) (cdr e)))
  (define blocks (program-blocks prog))
  (program
   (for/list ([b (in-list blocks)] [i (in-naturals)])
     (make-block
      (block-head b)
      (for/list ([it (in-list (block-items b))] [j (in-naturals)])
        (hash-ref table (list 'code i j) it))))
   (program-flows prog)))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (relax prog data layout-input #:max-rounds [max-rounds 64])
  (unless (program? prog)
    (error 'relax "program must be L4 output ((blocks ...) (flows ...)); got: ~e" prog))
  (let loop ([prog prog] [round 0])
    (define out (layout-program prog data layout-input))
    (define problems (layout-problems out))
    (define edits (collect-edits problems))
    (cond
      [(null? edits) out]
      [(>= round max-rounds)
       (error 'relax "did not converge in ~a rounds (last problems: ~e)"
              max-rounds problems)]
      [else (loop (apply-edits prog edits) (add1 round))])))
