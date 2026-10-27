#lang racket
;;; L5/forms.rkt
;;;
;;; 形式表: 每条 item 的字节数、类别、可达距离、是否需要 scratch。
;;; 只放数据 + 查询; 布局计算本身在 layout.rkt。
;;;
;;; 不在表里的助记符: 一律 4 字节; c.* 是显式判定的 2 字节。
;;; (真指令名单不在本层维护; 编不出来是后面编码层的事)

;; "是不是零寄存器" 只有一个来源: L3/insn.rkt (x0 / zero / 0)。
;; 布局层需要它, 因为 jump-far 要不要 scratch 取决于它的 link。
(require (only-in "../L3/insn.rkt" zero-register?))

(provide form? name? path? normalize-path
         label-form? align-form? bytes-form? fill-form? value-form? compressed-form?
         value-width value-payload
         label-expr? label-expr-chain label-expr-addend
         la-form? la-scratch
         jump-far-form? jump-far-link jump-far-scratch
         item-kind item-size
         branch-form? jump-form? indirect-form? control-form? control-target
         form-range scratch-hole?
         segment-form? segment-kind?)

;; ---------------------------------------------------------------------------
;; 基本形状
;; ---------------------------------------------------------------------------

(define (form? x) (and (pair? x) (list? x)))

(define (name? x) (or (symbol? x) (string? x) (number? x)))

(define (path? x) (and (list? x) (pair? x) (andmap name? x)))

;; 裸原子当单节链
(define (normalize-path x)
  (cond [(path? x) x] [(name? x) (list x)] [else #f]))

(define (label-form? x)
  (and (form? x) (eq? (car x) 'label) (path? (cdr x))))

(define (align-form? x)
  (and (form? x) (eq? (car x) 'align) (= 2 (length x))
       (exact-positive-integer? (cadr x))))

(define (byte? x) (and (exact-integer? x) (<= 0 x 255)))

(define (bytes-form? x)
  (and (form? x) (eq? (car x) 'bytes)
       (andmap byte? (cdr x))))

;; (fill 字节数 b): b 重复 字节数 次。和数据层的同一个名字。
(define (fill-form? x)
  (and (form? x) (eq? (car x) 'fill) (= 3 (length x))
       (exact-nonnegative-integer? (cadr x))
       (byte? (caddr x))))

;; (value 宽度 值): 宽度个字节, 值是什么由 L7 解释。
;; 尺寸现在就知道(= 宽度); 本层**不看**值是什么(整数还是地址字):
;;   整数                 -> L7 按目标端序落字节
;;   (label+ 链 加数)     -> 本层只解析地址看范围(下面), L7 落字节
(define value-width   cadr)
(define value-payload caddr)

(define (value-form? x)
  (and (form? x) (eq? (car x) 'value) (= 3 (length x))
       (memq (value-width x) '(1 2 4 8))
       #t))

;; 值里的地址表达式: (label+ 链 加数)。D1 会归一成这个形状(加数一定在)。
(define (label-expr? x)
  (and (form? x) (eq? (car x) 'label+) (= 3 (length x))
       (path? (label-expr-chain x))
       (exact-integer? (label-expr-addend x))
       #t))
(define label-expr-chain cadr)
(define label-expr-addend caddr)

;; C 扩展: 拼写以 c. 开头 (c.addi / c.j / c.beqz / c.nop ...), 一律 2 字节
(define (compressed-form? x)
  (and (form? x) (symbol? (car x))
       (string-prefix? (symbol->string (car x)) "c.")))

;; layout 输入的子句
(define (segment-form? x) (and (form? x) (eq? (car x) 'segment)))

;; 只认本层真的会区别对待的两种: code 与 data
(define (segment-kind? k) (memq k '(code data)))

;; ---------------------------------------------------------------------------
;; 分类
;; ---------------------------------------------------------------------------

(define branch-mnemonics   '(beq bne blt bge bltu bgeu c.beqz c.bnez branch-far branch-indirect))
(define jump-mnemonics     '(jal c.j c.jal jump-far))

(define (branch-form? x)   (and (form? x) (memq (car x) branch-mnemonics) #t))
(define (jump-form? x)     (and (form? x) (memq (car x) jump-mnemonics) #t))
(define (indirect-form? x) (and (form? x) (memq (car x) '(branch-indirect jump-far)) #t))

;; 有控制流目标、目标在最后一个操作数
(define (control-form? x) (or (branch-form? x) (jump-form? x)))
(define (control-target x) (and (control-form? x) (last x)))

;; ---------------------------------------------------------------------------
;; item 的类别: 决定它能落进哪种段 (P7)
;;   marker = label(不占字节, 两种段都行)
;;   both   = align(两种段都行)
;;   code   = 指令
;;   data   = bytes / fill / value
;; ---------------------------------------------------------------------------

(define (item-kind x)
  (cond
    [(label-form? x) 'marker]
    [(align-form? x) 'both]
    [(or (bytes-form? x) (fill-form? x) (value-form? x)) 'data]
    [else 'code]))                    ; 其余一律当成不透明的代码 item

;; ---------------------------------------------------------------------------
;; 字节数
;; ---------------------------------------------------------------------------

(define (item-size x)
  (cond
    [(label-form? x) 0]
    [(align-form? x) #f]              ; 由游标算
    [(bytes-form? x) (length (cdr x))]
    [(fill-form? x) (cadr x)]         ; 字节数 = 重复次数
    [(value-form? x) (value-width x)] ; 尺寸 = 宽度, 值等 L7
    [(compressed-form? x) 2]          ; c.* 必须先于 branch/jump 判, 也是 2 字节
    [(branch-form? x)
     (case (car x)
       [(branch-far) 8]
       [(branch-indirect) 12]
       [else 4])]
    [(jump-form? x)
     (case (car x)
       [(jump-far) 8]                 ; 8 = auipc + jalr; 远形式是尺寸契约的事
       [else 4])]
    [(eq? (car x) 'la) 8]             ; (la rd 链) 和 (la rd tmp 链) 同尺寸
    [else 4]))

;; ---------------------------------------------------------------------------
;; 可达距离 (字节); #f = 不设限 / 不是控制转移
;; ---------------------------------------------------------------------------

(define (form-range x)
  (cond
    [(branch-form? x)
     (case (car x)
       [(branch-far) 1048576]
       [(branch-indirect) #f]
       [(c.beqz c.bnez) 256]           ; C.BEQZ/C.BNEZ: ±256 B
       [else 4096])]
    [(jump-form? x)
     (case (car x)
       [(jump-far) #f]
       [(c.j c.jal) 2048]              ; C.J/C.JAL: ±2 KiB
       [else 1048576])]
    [else #f]))

;; ---------------------------------------------------------------------------
;; scratch: 三种, 不要混
;;
;; 1. 条件空槽 = "这条指令需要 scratch, 但没给":
;;      (branch-indirect a b L)    ; 条件分支远形式: 反向分支 + auipc+jalr, 总要 base
;;      (jump-far x0 L)            ; link 是零寄存器: auipc 没有落点, 必须借 base
;;    要不要 scratch 是 **link / 形式** 的函数, 所以 scratch-hole? 必须读操作数,
;;    不能只看"比满长度少一项"。报的是 problem(不是错误), 留给 L6 填。
;;
;; 2. 已填:
;;      (branch-indirect s a b L)
;;      (jump-far link s L)
;;
;; 3. 可选槽 = la 的 scratch, 缺省不代表缺陷:
;;      (la rd 链)        ; 短形式 auipc+addi 不需要 scratch; 远形式由 L7 挑
;;      (la rd tmp 链)    ; 显式指定, 给以后的 frame/regalloc 用
;;    所以 la 不进 scratch-hole?: 否则每个 la 都会报空槽。
;;
;; 三个形式都**显式**写出寄存器: 谁也不许从助记符里猜 link 或 scratch。
;; ---------------------------------------------------------------------------

;; (jump-far link L) / (jump-far link s L); call-far = (jump-far ra L), 不再单独存在
(define (jump-far-form? x)
  (and (form? x) (eq? (car x) 'jump-far) (memq (length x) '(3 4)) #t))
(define (jump-far-link x) (and (jump-far-form? x) (cadr x)))
(define (jump-far-scratch x) (and (jump-far-form? x) (= 4 (length x)) (caddr x)))

;; link 是零寄存器 -> 空槽; link 非零 -> auipc/jalr 都用它自己, 不需要 scratch
(define (far-jump-needs-scratch? x)
  (and (jump-far-form? x) (zero-register? (jump-far-link x))))

(define (scratch-hole? x)
  (cond
    [(and (form? x) (eq? (car x) 'branch-indirect)) (= 4 (length x))]
    [(far-jump-needs-scratch? x) (= 3 (length x))]
    [else #f]))

;; (la rd 链) / (la rd tmp 链): 带"可选 scratch"的形式
(define (la-form? x)
  (and (form? x)
       (eq? (car x) 'la)
       (memq (length x) '(3 4))
       (and (normalize-path (last x)) #t)))

;; 显式给出的 scratch; #f = 没写(不等于"不需要")
(define (la-scratch x)
  (and (la-form? x) (= 4 (length x)) (caddr x)))
