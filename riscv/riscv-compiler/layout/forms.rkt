#lang racket
;;; layout/forms.rkt
;;;
;;; 形式表: 每条 item 的字节数、类别、可达距离、必需操作数。
;;; 只放数据 + 查询; 布局计算本身在 layout.rkt。
;;;
;;; 指令长度统一交给 riscv-help/size.rkt；本层只处理数据 item 和对齐。
;;; (真指令名单不在本层维护; 编不出来是后面编码层的事)

(require "../sexp.rkt"
         (only-in "../code/insn.rkt"
                  branch-instruction? jump-instruction?
                  jump-target jump-target-position)
         (only-in "../target.rkt" target-xlen)
         ;; 指令长度统一在 riscv-help/size.rkt 计算；本层只把 target 转成 word-size。
         (only-in "../../riscv-help/size.rkt"
                  [instruction-size instruction-size*]
                  [la-pcrel-li-add-size shared-la-pcrel-li-add-size]))

(provide form? name? path? normalize-path
         label-form? align-form? pad-form? bytes-form? fill-form? value-form? compressed-form?
         reserve-form? reserve-size
         value-width value-payload
         arith-head? arith-form? address-expr? address-expr-chains
         la-pcrel-form?
         la-pcrel-li-add-form? la-pcrel-li-add-tmp la-pcrel-li-add-size
         branch-auipc-jalr-scratch
         jump-auipc-jalr-link jump-auipc-jalr-base
         item-kind item-size item-kind-allowed-in?
         branch-form? jump-form? control-form? control-target control-target-position
         form-range
         segment-form? segment-kind?)

;; ---------------------------------------------------------------------------
;; 基本形状
;; ---------------------------------------------------------------------------

;; label / bytes / align / pad / fill / value / byte? 的形状
;; 只在 ../sexp.rkt 定义（expand-data 与本层共用同一个边界），这里 re-provide。

;; (reserve n): n 字节**位置**, 不产生文件字节。
;; 只在 hole 段里合法: 洞之外的地方, 地址和字节必须一一对应。
(define (reserve-form? x)
  (and (form? x) (eq? (car x) 'reserve) (= 2 (length x))
       (exact-nonnegative-integer? (cadr x))))

(define reserve-size cadr)

;; (value 宽度 值): 宽度个字节, 值是什么由 encode 解释。
;; 尺寸现在就知道(= 宽度); 本层**不看**值是什么(整数还是地址字):
;;   整数                 -> encode 按目标端序落字节
;;   (链) / (+ …) / (- …)  -> check 求值看链是否存在, encode 落字节
(define value-width   cadr)
(define value-payload caddr)


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

;; 分支/跳转的名单不在这里重复: 直接借 code/insn.rkt 的分类。
;; 名字保留: 这是本层的词汇(尺寸/距离/目标位都按它查)。
(define (branch-form? x) (branch-instruction? x))
(define (jump-form? x)   (jump-instruction? x))

;; 有控制流目标。目标位置由 code/insn.rkt 按形式决定，
;; 不能假设它总在最后一个操作数。
(define (control-form? x) (or (branch-form? x) (jump-form? x)))
(define (control-target x) (and (control-form? x) (jump-target x)))
(define (control-target-position x) (and (control-form? x) (jump-target-position x)))

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
    ;; 指令 / 显式展开形式统一交给 riscv-help/size.rkt。
    ;; 不认识的 code item 由它按 4 字节兜底，和 encode 的不透明代码一致。
    [(and (form? x) (symbol? (car x)))
     (instruction-size* x #:word-size (target-xlen target))]
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
;; branch-jal = 反向分支 + jal, 真正的 jal 在 +4, 所以区间整体右移 4。
;; ---------------------------------------------------------------------------

(define (form-range x)
  (cond
    [(branch-form? x)
     (case (car x)
       [(branch-jal) '(-1048572 . 1048578)]
       [(branch-auipc-jalr) #f]
       [(c.beqz c.bnez) '(-256 . 254)]
       [else '(-4096 . 4094)])]
    [(jump-form? x)
     (case (car x)
       [(jump-auipc-jalr) #f]
       [(c.j c.jal) '(-2048 . 2046)]
       [else '(-1048576 . 1048574)])]
    [else #f]))

;; ---------------------------------------------------------------------------
;; 形式形状 / 必需操作数
;;
;; 所有 scratch/base/tmp 都是**必需操作数**, 没有可省略的空槽。
;; 缺操作数在 validate 的 arity 检查里挡掉; check 只检查寄存器值是否合法。
;; ---------------------------------------------------------------------------

;; 近 la: (la-pcrel rd expr) = auipc + addi
(define (la-pcrel-form? x)
  (and (form? x)
       (eq? (car x) 'la-pcrel)
       (= 3 (length x))
       (address-expr? (caddr x))))

;; 远 la: (la-pcrel-li-add rd tmp expr) = auipc rd,0 ; li tmp,delta ; add rd,rd,tmp
(define (la-pcrel-li-add-form? x)
  (and (form? x)
       (eq? (car x) 'la-pcrel-li-add)
       (= 4 (length x))
       (address-expr? (cadddr x))))

(define (la-pcrel-li-add-tmp x)
  (and (la-pcrel-li-add-form? x) (caddr x)))

;; 转成 target -> word-size；真正的尺寸在 riscv-help/size.rkt。
(define (la-pcrel-li-add-size target)
  (shared-la-pcrel-li-add-size #:word-size (target-xlen target)))

;; branch-auipc-jalr: (branch-auipc-jalr tmp cond rs1 rs2 target)
(define (branch-auipc-jalr-scratch x)
  (and (form? x) (eq? (car x) 'branch-auipc-jalr) (cadr x)))

;; jump-auipc-jalr: (jump-auipc-jalr link base target)
(define (jump-auipc-jalr-link x)
  (and (form? x) (eq? (car x) 'jump-auipc-jalr) (cadr x)))

(define (jump-auipc-jalr-base x)
  (and (form? x) (eq? (car x) 'jump-auipc-jalr) (caddr x)))
