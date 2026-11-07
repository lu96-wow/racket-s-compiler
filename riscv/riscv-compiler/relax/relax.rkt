#lang racket
;;; relax/relax.rkt
;;;
;;; 分支松弛: 把够不着的控制转移换成"更大一号"的形式, 直到全部够得着。
;;;
;;; 契约 (和 ARCHITECTURE 里 relax 的定义一致):
;;;   relax : program + data + layout 输入 -> measured-layout
;;;   layout 的产物里没有块结构, 改完也没法重排, 所以本层**驱动** layout, 而不是吃 layout 的产物。
;;;
;;; 只做一件事: 把 requests 里 needs-far 的 item 换成大一号的形式。
;;;
;;; 空槽(scratch-hole)**不填**: 那属于"动态内存布局 / 寄存器使用"那一层
;;; 远 la(la-too-far)会被升成 (la-far …), 同样留一个空槽给那一层
;;; (还没实现)。本层把空槽原样留在 requests 里:
;;; 升到 branch-indirect / (jump-far x0 …) 时就会产生一个新的空槽。
;;;
;;; loop:
;;;   out  = layout(prog, data, layout-spec)
;;;   edits = requests 里的 needs-far -> 换大一号 (far-step)
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
;;; 本层**不造 label、不拆块、不改 CFG**: 远形式是定长 item, 由 encode 展开成
;;; "反向条件分支 + 紧接着的跳转"(和 gas 的 md_convert_frag_branch 同形)。
;;; 因此 place 行永远有效, fallthrough 也不会因为松弛而断。

(require (only-in "../analyze/analyze.rkt" program program? program-blocks program-flows
                  block-head block-items make-block)
         (only-in "../layout/layout.rkt" layout-program layout-requests as-items)
         (only-in "../layout/forms.rkt" form? la-form?))

(provide relax
         far-step
         la-far-step)

;; ---------------------------------------------------------------------------
;; 提升表: 超范围 -> 大一号。语义不变, 尺寸只增。
;; ---------------------------------------------------------------------------

(define (far-step it)
  (and (form? it)
       (case (car it)
         ;; 压缩 -> 普通(2 -> 4); 还远就下一轮继续升
         ;; native 分支的目标在最前: (beq target rs1 rs2)
         [(c.beqz) (list 'beq (caddr it) (cadr it) 'x0)]
         [(c.bnez) (list 'bne (caddr it) (cadr it) 'x0)]
         [(c.j)    (list 'jal 'x0 (cadr it))]
         [(c.jal)  (list 'jal 'x1 (cadr it))]
         ;; b* -> 远分支(反向分支 + jal), 4 -> 8
         ;; native: (beq target rs1 rs2) -> (branch-far beq rs1 rs2 target)
         [(beq bne blt bge bltu bgeu)
          (list 'branch-far (car it) (caddr it) (cadddr it) (cadr it))]
         ;; riscv-opcodes pseudo 分支: 先换成对应的规范分支，再升远形式
         ;;   (ble L b a) = (bge L a b)
         ;;   (bgt L b a) = (blt L a b)
         [(ble)  (list 'branch-far 'bge  (cadddr it) (caddr it) (cadr it))]
         [(bleu) (list 'branch-far 'bgeu (cadddr it) (caddr it) (cadr it))]
         [(bgt)  (list 'branch-far 'blt  (cadddr it) (caddr it) (cadr it))]
         [(bgtu) (list 'branch-far 'bltu (cadddr it) (caddr it) (cadr it))]
         ;;   (beqz L rs) = (beq L rs x0)
         [(beqz) (list 'branch-far 'beq (caddr it) 'x0 (cadr it))]
         [(bnez) (list 'branch-far 'bne (caddr it) 'x0 (cadr it))]
         ;;   (blez L rs) = (bge L x0 rs)
         [(blez) (list 'branch-far 'bge 'x0 (caddr it) (cadr it))]
         [(bgtz) (list 'branch-far 'blt 'x0 (caddr it) (cadr it))]
         ;; 远分支 -> 间接远分支(反向分支 + auipc+jalr), 8 -> 12, 先留空槽
         [(branch-far)
          (list 'branch-indirect (cadr it) (caddr it) (cadddr it) (list-ref it 4))]
         ;; jal -> 远跳转, 4 -> 8
         ;;   (jal rd L) -> (jump-far rd L)      link 非零时它自己就是 base
         ;; rd 必须显式写: 汇编层不知道“省略 rd 时该用哪个 link”
         [(jal) (and (= 3 (length it)) (list 'jump-far (cadr it) (caddr it)))]
         ;; j L = jal x0, L
         [(j) (list 'jump-far 'x0 (cadr it))]
         [else #f])))

;; la 的远形式: 只是换形式, **不改 delta**(链还在 item 里, encode 到时候算)。
;;   (la rd 链)      -> (la-far rd 链)        空槽留给寄存器层
;;   (la rd tmp 链)  -> (la-far rd tmp 链)    保留前端给的 tmp
;; 尺寸从 8 涨到 far-la-size(常量上界), 所以本层只增不减。
(define (la-far-step it)
  (and (la-form? it)
       (if (= 4 (length it))
           (list 'la-far (cadr it) (caddr it) (cadddr it))
           (list 'la-far (cadr it) (last it)))))

;; ---------------------------------------------------------------------------
;; requests -> edits
;;
;; 本层能改两类, 都是“换个更大的定长形式”:
;;   (needs-far  段 偏移 item 距离 origin)   控制转移够不着
;;   (la-too-far 段 偏移 item 距离 origin)   近形式 auipc+addi 够不着
;; 其它 requests(scratch-hole)原样留着(见文件头)。
;; ---------------------------------------------------------------------------

;; request 的最后一个字段是定位: (code 块下标 项下标)，layout 在 measure 时记下来的。
(define (request-origin request)
  (define tail (last request))
  (and (pair? tail) (eq? (car tail) 'code) tail))

(define (edit-for p)
  (case (car p)
    [(needs-far) (far-step (cadddr p))]
    [(la-too-far) (la-far-step (cadddr p))]
    [else #f]))

(define (collect-edits requests)
  (append*
   (for/list ([p (in-list requests)])
     (define o (request-origin p))
     (define new (edit-for p))
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

(define (relax target prog data layout-input
               #:externs [externs '()]
               #:max-rounds [max-rounds 64])
  (unless (program? prog)
    (error 'relax "program must be dce output ((blocks ...) (flows ...)); got: ~e" prog))
  (let loop ([prog prog] [round 0])
    (define out (layout-program target prog data layout-input externs))
    (define requests (layout-requests out))
    (define edits (collect-edits requests))
    (cond
      [(null? edits) out]
      [(>= round max-rounds)
       (error 'relax "did not converge in ~a rounds (last requests: ~e)"
              max-rounds requests)]
      [else (loop (apply-edits prog edits) (add1 round))])))
