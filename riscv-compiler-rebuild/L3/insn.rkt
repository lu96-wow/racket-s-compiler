#lang racket
;;; L3/insn.rkt
;;;
;;; L2 之后代码就是指令 + label + 少量指令头。这里只做分类, 不改写。
;;;
;;; 分类决定 CFG 的形状:
;;;   - 分支        (beq a b L)   两条边: 目标 + 顺序
;;;   - 直接跳转    (jal x0 L)    一条边: 目标(无顺序边)
;;;   - 调用        (jal ra L)    两条边: 目标 + 顺序
;;;   - 间接跳转    (jalr ...)    目标不可知: 只有顺序边, 并让整张图"有间接跳转"
;;;   - 陷阱        (ecall) 可能返回 -> 顺序边; (ebreak) 停住 -> 无边
;;;   - 屏障        (bytes ...) 等数据形式: 不跨过它做分析(段归属在 L4, 与 CFG 无关)
;;;
;;; 不认识的指令一律当普通指令: 不进分析, 原样保留。

(provide form?
         name? path? normalize-path
         label-form? label-path
         barrier-heads barrier-form?
         branch-instruction? jump-instruction? indirect-instruction?
         trap-instruction? ends-block?
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

(define branch-mnemonics   '(beq bne blt bge bltu bgeu))
(define jump-mnemonics     '(jal))
(define indirect-mnemonics '(jalr))
(define trap-mnemonics     '(ecall ebreak))

;; 不是指令: 出现就当作分段屏障, 不跨过它搬代码
;; (段/place 归属是 L4 的事; 这里只管"别跨过数据搬代码")
(define barrier-heads
  '(bytes reserve align quote))

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

(define (barrier-form? x) (head-in? x barrier-heads))

(define (branch-instruction? x)   (head-in? x branch-mnemonics))
(define (jump-instruction? x)     (head-in? x jump-mnemonics))
(define (indirect-instruction? x) (head-in? x indirect-mnemonics))
(define (trap-instruction? x)     (head-in? x trap-mnemonics))

;; 这条指令之后必须开新块
(define (ends-block? x)
  (or (branch-instruction? x)
      (jump-instruction? x)
      (indirect-instruction? x)
      (trap-instruction? x)))

;; (jal L) 省略 rd 时按 ra 算
(define (jump-register x)
  (if (= 3 (length x)) (cadr x) 'ra))

;; (jal [rd] L) / (beq a b L) 的目标都在最后
(define (jump-target x) (last x))

(define (zero-register? r)
  (or (eq? r 'x0) (eq? r 'zero) (equal? r 0)))

;; 无条件直接跳转: 目标确定且不回来
(define (unconditional-jump? x)
  (and (jump-instruction? x)
       (zero-register? (jump-register x))))
