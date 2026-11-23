#lang racket
;;; code/insn.rkt
;;;
;;; native 指令 + label 的分类。这里只做分类, 不改写。
;;; 布局/编码需要知道“哪条是分支/跳转、目标在哪”；这里不建 CFG。
;;;
;;; 操作数顺序是 riscv-opcodes native 顺序:
;;;   - 分支        (beq L a b) / (c.beqz a L)   两条边: 目标 + 顺序
;;;   - 直接跳转    (jal x0 L) / (c.j L)          一条边: 目标(无顺序边)
;;;   - 调用        (jal x1 L) / (c.jal L)        两条边: 目标 + 顺序
;;;   - 间接跳转    (jalr ...) / (c.jr r) / (c.jalr r)
;;;                 目标不可知: c.jr 无顺序边, c.jalr/jalr 有; 图记为"有间接跳转"
;;;   - 陷阱        (ecall) 可能返回 -> 顺序边; (ebreak) / (c.ebreak) 停住 -> 无边
;;;
;;; 目标位置不再写死为 last: 普通分支的 bimm12 在 native 顺序里通常在前面。
;;; 不认识的指令一律当普通指令: 不进分析, 原样保留。

(require "../sexp.rkt"
         ;; 寄存器身份只有一个来源(整数 / x 名 / 别名都指向同一个寄存器)
         (only-in "../../riscv-asm/base/register.rkt" zero-register?))

(provide form?
         name? path? normalize-path
         label-form? label-path
         branch-instruction? jump-instruction? indirect-instruction?
         trap-instruction? ends-block? falls-through?
         unconditional-jump? jump-target jump-target-position jump-register
         check-transfer-arity!
         zero-register?)

;; 真列表(代码形状)


;; 名字: label 的链上一节(可以是 symbol / string / number)


;; 链: 非空名字列表, 例如 (a g)。label 与跳转目标都用它做身份。


;; 裸原子当单节链看: g 与 (g) 等价


;; ---------------------------------------------------------------------------
;; 分类表(唯一的名单, 改这里)
;; ---------------------------------------------------------------------------

(define branch-mnemonics
  '(beq bne blt bge bltu bgeu
    ble bleu bgt bgtu
    beqz bnez blez bgtz
    c.beqz c.bnez
    branch-jal branch-auipc-jalr))
(define jump-mnemonics     '(jal j c.j c.jal jump-auipc-jalr))
(define indirect-mnemonics '(jalr jr c.jr c.jalr))
(define trap-mnemonics     '(ecall ebreak c.ebreak))
;; ---------------------------------------------------------------------------
;; 查询
;; ---------------------------------------------------------------------------

(define (head-in? x heads)
  (and (form? x) (memq (car x) heads) #t))

;; (label a b) 表示链 (a b); (label) 不算 label
;; label-form? 的形状由 ../sexp.rkt 定义（与 expand-data / layout 同一个边界）。

(define (label-path x) (cdr x))

(define (branch-instruction? x)   (head-in? x branch-mnemonics))
(define (jump-instruction? x)     (head-in? x jump-mnemonics))
(define (indirect-instruction? x) (head-in? x indirect-mnemonics))
(define (trap-instruction? x)     (head-in? x trap-mnemonics))

;; 执行会不会顺序落到**物理下一条**?
;;   分支: 会
;;   jal x1 / c.jal / c.jalr / jalr rd≠x0: 会(返回地址 = pc+4)
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

;; 固定 arity 的显式形式。
;; 省略写法必须挡在入口: 否则 jump-register 会把目标 label 当成 link 寄存器,
;; 控制流静默算错; scratch/base 也一样, 不能靠“少一项”来推断。
(define (check-transfer-arity! x)
  (when (form? x)
    (case (car x)
      [(jal)
       (unless (= 3 (length x))
         (error 'validate
                "jal 必须显式写 link: (jal rd L)，收到 ~s"
                x))]
      [(branch-jal)
       (unless (= 5 (length x))
         (error 'validate
                "branch-jal 形状必须是 (branch-jal cond rs1 rs2 L)，收到 ~s"
                x))]
      [(branch-auipc-jalr)
       (unless (= 6 (length x))
         (error 'validate
                "branch-auipc-jalr 形状必须是 (branch-auipc-jalr tmp cond rs1 rs2 L)，收到 ~s"
                x))]
      [(jump-auipc-jalr)
       (unless (= 4 (length x))
         (error 'validate
                "jump-auipc-jalr 形状必须是 (jump-auipc-jalr link base L)，收到 ~s"
                x))]
      [(la-pcrel)
       (unless (= 3 (length x))
         (error 'validate
                "la-pcrel 形状必须是 (la-pcrel rd expr)，收到 ~s"
                x))]
      [(la-pcrel-li-add)
       (unless (= 4 (length x))
         (error 'validate
                "la-pcrel-li-add 形状必须是 (la-pcrel-li-add rd tmp expr)，收到 ~s"
                x))]
      [else (void)])))

;; 这条指令写哪个链接寄存器? 它决定会不会顺序落下, 也决定是不是无条件跳转。
;; jal / jalr / jump-auipc-jalr 都有显式 rd, 不猜: (jal L) 这种“省略 rd 按调用算”
;; 是 GAS 的简写, 而“省略 rd 时该写哪个 link”本身是 ABI —— 汇编层不认。
;; 压缩形式没有显式 rd, 但那个 rd 是 ISA 定死的: c.j / c.jr 写 x0, c.jal / c.jalr 写 x1。
(define (jump-register x)
  (and (form? x)
       (case (car x)
         [(jal)      (and (= 3 (length x)) (cadr x))]
         [(jalr)     (cadr x)]
         [(jump-auipc-jalr) (and (= 4 (length x)) (cadr x))]
         [(j)        'x0]
         [(jr)       'x0]
         [(c.j)      'x0]
         [(c.jal)    'x1]
         [(c.jr)     'x0]
         [(c.jalr)   'x1]
         [else #f])))

;; 目标操作数在 cdr 里的位置(0 基)。
;;
;;   native 分支: (beq L a b) / (ble L b a) / (beqz L a) -> 目标在 cdr 的第一个
;;   压缩分支:   (c.beqz a L)                              -> 目标在 cdr 的第二个
;;   jal:        (jal rd L)                         rd 必须显式写(不猜 ABI)
;;   显式远形式: 仍是各自的内部顺序，目标在最后
(define (jump-target-position x)
  (and (form? x)
       (case (car x)
         [(beq bne blt bge bltu bgeu
               ble bleu bgt bgtu
               beqz bnez blez bgtz)
          0]
         [(c.beqz c.bnez) 1]
         [(c.j c.jal) 0]
         [(j) 0]
         [(jal) (and (= 3 (length x)) 1)]
         [(branch-jal branch-auipc-jalr jump-auipc-jalr) (sub1 (length (cdr x)))]
         [else #f])))

(define (jump-target x)
  (define p (jump-target-position x))
  (and p (list-ref x (add1 p))))


;; 无条件直接跳转: 目标确定且不回来
(define (unconditional-jump? x)
  (and (jump-instruction? x)
       (zero-register? (jump-register x))))
