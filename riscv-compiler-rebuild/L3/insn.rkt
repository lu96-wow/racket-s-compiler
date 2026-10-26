#lang racket
;;; L3/insn.rkt
;;;
;;; L2 之后代码就是指令 + label。这里只做分类, 不改写。
;;;
;;; 分类决定 CFG 的形状:
;;;   - 分支        (beq a b L) / (c.beqz a L)   两条边: 目标 + 顺序
;;;   - 直接跳转    (jal x0 L) / (c.j L)          一条边: 目标(无顺序边)
;;;   - 调用        (jal ra L) / (c.jal L)        两条边: 目标 + 顺序
;;;   - 间接跳转    (jalr ...) / (c.jr r) / (c.jalr r)
;;;                 目标不可知: c.jr 无顺序边, c.jalr/jalr 有; 图记为"有间接跳转"
;;;   - 陷阱        (ecall) 可能返回 -> 顺序边; (ebreak) / (c.ebreak) 停住 -> 无边
;;;
;;; 不认识的指令一律当普通指令: 不进分析, 原样保留。

(provide form?
         name? path? normalize-path
         label-form? label-path
         branch-instruction? jump-instruction? indirect-instruction?
         trap-instruction? ends-block? falls-through?
         unconditional-jump? jump-target jump-register
         zero-register?)

;; 真列表(代码形状)
(define (form? x)
  (and (pair? x) (list? x)))

;; 名字: label 的链上一节(可以是 symbol / string / number)
(define (name? x)
  (or (symbol? x) (string? x) (number? x)))

;; 链: 非空名字列表, 例如 (a g)。label 与跳转目标都用它做身份。
(define (path? x)
  (and (list? x) (pair? x) (andmap name? x)))

;; 裸原子当单节链看: g 与 (g) 等价
(define (normalize-path x)
  (cond
    [(path? x) x]
    [(name? x) (list x)]
    [else #f]))

;; ---------------------------------------------------------------------------
;; 分类表(唯一的名单, 改这里)
;; ---------------------------------------------------------------------------

(define branch-mnemonics   '(beq bne blt bge bltu bgeu c.beqz c.bnez))
(define jump-mnemonics     '(jal c.j c.jal))
(define indirect-mnemonics '(jalr c.jr c.jalr))
(define trap-mnemonics     '(ecall ebreak c.ebreak))
;; ---------------------------------------------------------------------------
;; 查询
;; ---------------------------------------------------------------------------

(define (head-in? x heads)
  (and (form? x) (memq (car x) heads) #t))

;; (label a b) 表示链 (a b); (label) 不算 label
(define (label-form? x)
  (and (form? x)
       (eq? (car x) 'label)
       (path? (cdr x))))

(define (label-path x) (cdr x))

(define (branch-instruction? x)   (head-in? x branch-mnemonics))
(define (jump-instruction? x)     (head-in? x jump-mnemonics))
(define (indirect-instruction? x) (head-in? x indirect-mnemonics))
(define (trap-instruction? x)     (head-in? x trap-mnemonics))

;; 执行会不会顺序落到**物理下一条**?
;;   分支: 会
;;   jal ra / c.jal / c.jalr / jalr rd≠x0: 会(返回地址 = pc+4)
;;   jal x0 / c.j / c.jr: 不回来 -> 不会
;;   ecall: 会; ebreak / c.ebreak: 不会
(define (falls-through? x)
  (cond
    [(branch-instruction? x) #t]
    [(or (jump-instruction? x) (indirect-instruction? x))
     (not (zero-register? (jump-register x)))]
    [(trap-instruction? x) (eq? (car x) 'ecall)]
    [else #t]))

;; 这条指令之后必须开新块
(define (ends-block? x)
  (or (branch-instruction? x)
      (jump-instruction? x)
      (indirect-instruction? x)
      (trap-instruction? x)))

;; 这条指令写哪个链接寄存器? 它决定会不会顺序落下, 也决定是不是无条件跳转。
;;   jal / jalr 有显式 rd; (jal L) 省略 rd 时按 ra 算
;;   压缩形式没有显式 rd: c.j / c.jr 不写(x0), c.jal / c.jalr 写 ra
(define (jump-register x)
  (and (form? x)
       (case (car x)
         [(jal)    (if (= 3 (length x)) (cadr x) 'ra)]
         [(jalr)   (cadr x)]
         [(c.j)    'x0]
         [(c.jal)  'ra]
         [(c.jr)   'x0]
         [(c.jalr) 'ra]
         [else #f])))

;; (jal [rd] L) / (beq a b L) / (c.beqz a L) / (c.j L): 目标都在最后
(define (jump-target x) (last x))

(define (zero-register? r)
  (or (eq? r 'x0) (eq? r 'zero) (equal? r 0)))

;; 无条件直接跳转: 目标确定且不回来
(define (unconditional-jump? x)
  (and (jump-instruction? x)
       (zero-register? (jump-register x))))
