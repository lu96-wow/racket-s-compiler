#lang racket
;;; layout/forms.rkt
;;;
;;; 形式表: 每条 item 的字节数、类别、可达距离、是否需要 scratch。
;;; 只放数据 + 查询; 布局计算本身在 layout.rkt。
;;;
;;; 不在表里的助记符: 一律 4 字节; c.* 是显式判定的 2 字节。
;;; (真指令名单不在本层维护; 编不出来是后面编码层的事)

;; "是不是零寄存器" 只有一个来源: analyze/insn.rkt (x0 / zero / 0)。
;; 布局层需要它, 因为 jump-far 要不要 scratch 取决于它的 link。
(require "../sexp.rkt"
         (only-in "../analyze/insn.rkt"
                  zero-register? branch-instruction? jump-instruction?)
         (only-in "../target.rkt" target-xlen)
         ;; li 的尺寸由展开器的主人给: 常量就在 item 里, 所以这是**精确值**,
         ;; 不是上界。展开长度和 XLEN 有关, 所以用调用方传进来的 target。
         (only-in "../../riscv-help/main.rkt" li-size))

(provide form? name? path? normalize-path
         label-form? align-form? pad-form? bytes-form? fill-form? value-form? compressed-form?
         reserve-form? reserve-size
         value-width value-payload
         arith-head? arith-form? address-expr? address-expr-chains
         la-form? la-scratch
         jump-far-form? jump-far-link jump-far-scratch
         item-kind item-size item-kind-allowed-in?
         branch-form? jump-form? control-form? control-target
         form-range scratch-hole?
         segment-form? segment-kind?)

;; ---------------------------------------------------------------------------
;; 基本形状
;; ---------------------------------------------------------------------------







;; 裸原子当单节链


(define (label-form? x)
  (and (form? x) (eq? (car x) 'label) (path? (cdr x))))

(define (align-form? x)
  (and (form? x) (eq? (car x) 'align) (= 2 (length x))
       (exact-positive-integer? (cadr x))))

;; (pad n): "这里要补 n 个字节" —— 是**事实**, 不是要求。
;; `align` 是输入侧的请求, 本层度量时把它换算成 pad 写进产物。
(define (pad-form? x)
  (and (form? x) (eq? (car x) 'pad) (= 2 (length x))
       (exact-nonnegative-integer? (cadr x))))

(define (byte? x) (and (exact-integer? x) (<= 0 x 255)))

(define (bytes-form? x)
  (and (form? x) (eq? (car x) 'bytes)
       (andmap byte? (cdr x))))

;; (fill 字节数 b): b 重复 字节数 次。和数据层的同一个名字。
(define (fill-form? x)
  (and (form? x) (eq? (car x) 'fill) (= 3 (length x))
       (exact-nonnegative-integer? (cadr x))
       (byte? (caddr x))))

;; (reserve n): n 字节**位置**, 不产生文件字节。
;; 只在 hole 段里合法: 洞之外的地方, 地址和字节必须一一对应。
(define (reserve-form? x)
  (and (form? x) (eq? (car x) 'reserve) (= 2 (length x))
       (exact-nonnegative-integer? (cadr x))))

(define reserve-size cadr)

;; (value 宽度 值): 宽度个字节, 值是什么由 encode 解释。
;; 尺寸现在就知道(= 宽度); 本层**不看**值是什么(整数还是地址字):
;;   整数                 -> encode 按目标端序落字节
;;   (链) / (+ …) / (- …)  -> 本层求值看范围(下面), encode 落字节
(define value-width   cadr)
(define value-payload caddr)

(define (value-form? x)
  (and (form? x) (eq? (car x) 'value) (= 3 (length x))
       (memq (value-width x) '(1 2 4 8))
       #t))

;; C 扩展: 拼写以 c. 开头 (c.addi / c.j / c.beqz / c.nop ...), 一律 2 字节
(define (compressed-form? x)
  (and (form? x) (symbol? (car x))
       (string-prefix? (symbol->string (car x)) "c.")))

;; layout 输入的子句
(define (segment-form? x) (and (form? x) (eq? (car x) 'segment)))

;; 三种, 都只回答两个问题: 哪些 item 合法、对齐补出来的空间怎么落。
;;   code = 可执行;  data = 数据;  hole = 只有位置, 文件里没有字节。
;; hole 的"内容"不归本产物定义: 由加载器 / 程序 / 硬件决定。
(define (segment-kind? k) (memq k '(code data hole)))

;; ---------------------------------------------------------------------------
;; 分类
;; ---------------------------------------------------------------------------

;; 分支/跳转的名单不在这里重复: 直接借 analyze/insn.rkt 的分类。
;; (以前这里抄了一份, 加远形式时只改了一边, 块边界全错。)
;; 名字保留: 这是本层的词汇(尺寸/距离/目标位都按它查)。
(define (branch-form? x) (branch-instruction? x))
(define (jump-form? x)   (jump-instruction? x))

;; 有控制流目标、目标在最后一个操作数
(define (control-form? x) (or (branch-form? x) (jump-form? x)))
(define (control-target x) (and (control-form? x) (last x)))

;; ---------------------------------------------------------------------------
;; item 的类别: 决定它能落进哪种段 (P7)
;;   marker       = label, 不占字节, 三种段都行
;;   align        = align(请求), 补出来的是 pad 还是 reserve 由段 kind 定
;;   pad          = pad(事实) = 补 n 个字节, code / data 收, hole 不收
;;   space        = reserve, 只推进位置, 只有 hole 收
;;   materialized = bytes / fill / value, "数据 item", 只有 data 收
;;   code         = 指令, 只有 code 收
;; 判合法性**只看这张表**, 不在这里塞策略: item-kind-allowed-in? 是唯一入口。
;;
;; pad 与 materialized 刻意分开: pad 是本层自己产的对齐事实(代码段也需要),
;; materialized 是别人写进来的数据。RISC-V 这边 code 段不收数据。
;; ---------------------------------------------------------------------------

(define (item-kind x)
  (cond
    [(label-form? x) 'marker]
    [(align-form? x) 'align]
    [(pad-form? x) 'pad]
    [(reserve-form? x) 'space]
    [(or (bytes-form? x) (fill-form? x) (value-form? x)) 'materialized]
    [else 'code]))                    ; 其余一律当成不透明的代码 item

;; 段 kind -> 它收哪些 item 类。
;; hole 收 space 不收 pad / materialized / code: 洞里的地址没有字节可对应。
(define (item-kind-allowed-in? ik kind)
  (and (case kind
         [(code) (memq ik '(marker align pad code))]
         [(data) (memq ik '(marker align pad materialized))]
         [(hole) (memq ik '(marker align space))]
         [else #f])
       #t))

;; ---------------------------------------------------------------------------
;; 字节数
;; ---------------------------------------------------------------------------

(define (item-size target x)
  (cond
    [(label-form? x) 0]
    [(align-form? x) #f]              ; 由游标算(度量时换算成 pad)
    [(pad-form? x) (cadr x)]          ; 补多少个字节
    [(bytes-form? x) (length (cdr x))]
    [(fill-form? x) (cadr x)]         ; 字节数 = 重复次数
    [(reserve-form? x) (reserve-size x)] ; 只占位置: 尺寸照样要算进游标
    [(value-form? x) (value-width x)] ; 尺寸 = 宽度, 值等 encode
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
    [(eq? (car x) 'li) (li-size (caddr x) #:word-size (target-xlen target))]  ; 常量决定尺寸: 4 / 8 / 12 / 16 / … / 32
    [(eq? (car x) 'la) 8]             ; 近形式 auipc+addi; 够不着由 layout 留 la-too-far request
    [else 4]))

;; ---------------------------------------------------------------------------
;; 可达距离: 区间 (lo . hi), #f = 不设限 / 不是控制转移
;;
;; 不是 ±幅度: RISC-V 的偏移都是偶数(2/4 字节指令), 所以
;;   B 型   : [-4096, 4094]     (LLVM 写成 isInt<13>, 偶数偏移下等价)
;;   CB 型  : [-256,  254]
;;   CJ 型  : [-2048, 2046]
;;   JAL    : [-1048576, 1048574]
;; 用区间是为了不放过 +4096 这种"幅度看起来够、其实编不出来"的边界。
;;
;; 远形式的区间要把自己的偏置算进去: branch-far = 反向分支 + jal,
;; 真正的 jal 在 +4, 所以区间整体右移 4。
;; ---------------------------------------------------------------------------

(define (form-range x)
  (cond
    [(branch-form? x)
     (case (car x)
       [(branch-far) '(-1048572 . 1048578)]
       [(branch-indirect) #f]
       [(c.beqz c.bnez) '(-256 . 254)]
       [else '(-4096 . 4094)])]
    [(jump-form? x)
     (case (car x)
       [(jump-far) #f]
       [(c.j c.jal) '(-2048 . 2046)]
       [else '(-1048576 . 1048574)])]
    [else #f]))

;; ---------------------------------------------------------------------------
;; scratch: 三种, 不要混
;;
;; 1. 条件空槽 = "这条指令需要 scratch, 但没给":
;;      (branch-indirect <cond> a b L)   ; 远分支: 反向分支 + auipc+jalr, 总要 base
;;      (jump-far x0 L)                  ; link 是零寄存器: auipc 没有落点, 必须借 base
;;    要不要 scratch 是 **link / 形式** 的函数, 所以 scratch-hole? 必须读操作数,
;;    不能只看"比满长度少一项"。报的是 request(不是错误), 留给寄存器层填。
;;
;; 2. 已填:
;;      (branch-indirect s <cond> a b L)
;;      (jump-far link s L)
;;
;; 3. 可选槽 = la 的 scratch, 缺省不代表缺陷:
;;      (la rd 链)        ; 短形式 auipc+addi 不需要 scratch; 远形式由 encode 挑
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
    [(and (form? x) (eq? (car x) 'branch-indirect)) (= 5 (length x))]
    [(far-jump-needs-scratch? x) (= 3 (length x))]
    [else #f]))

;; (la rd 链) / (la rd tmp 链): 带"可选 scratch"的形式
;; (la rd 地址表达式) / (la rd tmp 地址表达式)
(define (la-form? x)
  (and (form? x)
       (eq? (car x) 'la)
       (memq (length x) '(3 4))
       (address-expr? (last x))))

;; 显式给出的 scratch; #f = 没写(不等于"不需要")
(define (la-scratch x)
  (and (la-form? x) (= 4 (length x)) (caddr x)))
