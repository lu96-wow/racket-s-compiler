#lang racket
;;; encode/encode.rkt
;;;
;;; 最后一步: bound-layout -> (build ...)，每个段一坨字节。
;;;
;;; 输入是 bind-labels 之后的 layout:
;;;   ((phase bound)
;;;    (segments (segment (name s) (kind code) (start x) (end y) (align n)
;;;                       (items (offset k item) ...) (size n)) ...)
;;;    (anchors ...)
;;;    (symbols (symbol 链 段名 偏移 绝对地址) ...)
;;;    (requests)
;;;    (problems))
;;;
;;; 每条 item 怎么落成字节:
;;;   label     不占字节
;;;   pad n     补 n 字节: code 段填合法指令(nop / c.nop), 其余填 0
;;;   bytes     原样
;;;   fill n b  n 个 b
;;;   value w v w 字节, 端序由 target.rkt 定; v 是整数或地址表达式
;;;   reserve n hole 段里的"n 字节位置": 不写字节
;;;   真指令    riscv-asm 编码; 目标地址 = 符号表 + 加数, 分支/跳转取相对偏移
;;;   远形式 / li / la   先由 riscv-help 展开成几条真指令, 再逐条编码
;;;
;;; kind = hole 的段走另一条路: 地址范围存在, 文件里没有字节,
;;; 产物是 (size n) + (bytes #"")。洞的内容不归本产物定义。
;;;
;;; (offset k ...) 是**断言**: 写出去的字节数必须正好让它落在 k。
;;; 不符说明 layout 和 encode 对尺寸的理解不一致, 直接报错(这是抓这类 bug 的地方)。

(require (only-in "../layout/layout.rkt"
                  layout-problems layout-requests layout-phase layout-segments)
         "../layout/forms.rkt"
         (only-in "../bind-labels/bind.rkt"
                  bound-layout? layout-symbols layout-link layout-provides
                  symbol-row symbol-address eval-symbol-address)
         (only-in "../../riscv-help/main.rkt"
                  jump-jal jump-auipc-jalr zero-register?
                  li load-pcrel load-pcrel-far)
         (only-in "../../riscv-asm/base/register.rkt" register->number)
         "../target.rkt"
         "native-help.rkt"
         "insn.rkt")

(provide encode-layout)

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (segment-field seg key) (cadr (assoc key (cdr seg))))
(define (segment-items seg) (cdr (assoc 'items (cdr seg))))

;; (offset k ...) 是断言: 走到这条 item 时, 已落的位置必须正好是 k。
;; 两种段(材料化 / hole)共用同一条断言, 所以两边的报错不会分叉。
(define (check-offset! name at reached it)
  (unless (= at reached)
    (error 'encode
           "段 ~a 的偏移不一致: layout 说 ~a, encode 算到 ~a (item ~e)"
           name at reached it)))

;; 符号行是 (symbol 链 段名 偏移 绝对地址); 查找/取地址复用 bind-labels 的实现
(define (resolve-symbol symbols chain addend)
  (define row (symbol-row symbols chain))
  (unless row (error 'encode "undefined symbol: ~s" chain))
  (+ (symbol-address row) addend))

(define (value->bytes w v symbols)
  (integer->bytes w (eval-symbol-address v symbols)))

;; 操作数: 寄存器名/立即数原样交给 insn.rkt;
;; 控制转移的目标是链 -> 在原位置换成相对当前 item 的偏移。
(define (operands-at it here symbols)
  (cond
    [(control-form? it)
     (define target (normalize-path (control-target it)))
     (define pos (control-target-position it))
     (define ops (cdr it))
     (append (take ops pos)
             (list (- (resolve-symbol symbols target 0) here))
             (drop ops (add1 pos)))]
    [else (cdr it)]))

;; ---------------------------------------------------------------------------
;; 远形式: 交给 riscv-help 展开成真指令
;; ---------------------------------------------------------------------------

;; 远形式的目标寄存器由 riscv-help 解释: 它内部用 zero-register? 判"link 是不是零寄存器",
;; 整数 / x 名 / 别名三种写法都能正确分派, 这里原样传下去即可。
;; 输出寄存器一律用架构名(x0..x31), 不写 ABI 别名。

(define (branch-distance it here symbols index)
  (define target (normalize-path (list-ref it index)))
  (- (resolve-symbol symbols target 0) here))

;; (branch-far cond rs1 rs2 L) = 反向条件分支 + jal
(define (encode-far-branch it here symbols)
  (define cond (cadr it))
  (define d (branch-distance it here symbols 4))
  (native-branch-long cond
                      (register->number (caddr it))
                      (register->number (cadddr it))
                      d
                      (lambda (offset) (jump-jal 'x0 offset))))

;; (branch-indirect s cond rs1 rs2 L) = 反向条件分支 + auipc+jalr
(define (encode-indirect-branch it here symbols)
  (define s (cadr it))
  (define cond (caddr it))
  (define d (branch-distance it here symbols 5))
  (native-branch-long cond
                      (register->number (cadddr it))
                      (register->number (list-ref it 4))
               d
               (lambda (offset) (jump-auipc-jalr 'x0 offset #:scratch (list s)))))

;; (jump-far link [s] L): link 非零时它自己就是 auipc 的落点
(define (encode-far-jump it here symbols)
  (define link (cadr it))
  (define target (normalize-path (last it)))
  (define d (- (resolve-symbol symbols target 0) here))
  (cond
    ;; 空槽没人填。判据用 forms 的 scratch-hole?, 和 layout 报 scratch-hole
    ;; request 用的是同一个: 不再在这里拄一份"少一个且 link 是零寄存器"。
    [(scratch-hole? it)
     (error 'encode "(jump-far ~a …) 的空槽没人填, 不能编码" link)]
    [(zero-register? link)
     (jump-auipc-jalr 'x0 d #:scratch (list (caddr it)))]
    [else (jump-auipc-jalr link d)]))

;; (la-far rd tmp 链): 强制远形式, 然后用 nop 补到 forms.rkt 定的固定尺寸。
;; 为什么要补: layout 记的是**上界**(li 的最坏情况), 实际 li 往往更短;
;; 尺寸必须和 layout 说的一致, 否则后面的 offset 全错。
(define (far-la-expansion target it here symbols)
  (define rd (cadr it))
  (define tmp (caddr it))
  (define d (- (eval-symbol-address (last it) symbols) here))
  (define insns (load-pcrel-far rd d #:word-size (target-xlen target) #:scratch (list tmp)))
  (define used (* 4 (length insns)))
  (define total (item-size target it))
  (unless (<= used total)
    (error 'encode "(la-far …) 展开成 ~a 字节, 超过 layout 给的 ~a" used total))
  (values insns (- total used)))

;; 一条代码 item 可能展开成几条真指令, 逐条交给 emit! 写出去。
;;   plain  : 操作数里可能有链, 先换成偏移
;;   远形式 / li / la : riscv-help 已经给出带数字偏移的真指令
(define (encode-code target it here symbols emit!)
  (define (emit-instruction! name operands)
    (define-values (word n) (encode-instruction target name operands))
    (emit! (integer->bytes n word)))
  (define (emit-all! insns)
    (for ([i (in-list insns)]) (emit-instruction! (car i) (cdr i))))
  (case (car it)
    [(la-far)
     (define-values (insns pad) (far-la-expansion target it here symbols))
     (emit-all! insns)
     (emit! (padding-bytes target 'code pad))]
    [(branch-far)      (emit-all! (encode-far-branch it here symbols))]
    [(branch-indirect) (emit-all! (encode-indirect-branch it here symbols))]
    [(jump-far)        (emit-all! (encode-far-jump it here symbols))]
    ;; (li rd 常量): 尺寸由 layout 用 li-size 精确算过, 这里用同一个展开器
    [(li) (emit-all! (li (cadr it) (caddr it) #:word-size (target-xlen target)))]
    ;; (la rd [tmp] 链): 近形式 8 字节; layout 已经保证够得着, 所以不需要 scratch
    [(la) (define d (- (eval-symbol-address (last it) symbols) here))
          (emit-all! (load-pcrel (cadr it) d))]
    [else (emit-instruction! (car it) (operands-at it here symbols))]))

;; ---------------------------------------------------------------------------
;; 段
;; ---------------------------------------------------------------------------

;; hole 段: 地址范围存在, 文件里没有字节。
;; 本层**不解释**这些地址里放的是什么 —— 由加载器 / 程序 / 硬件定义, 与产物无关;
;; 这里只保证"位置"被完整推进了, 然后交出一段空字节。
;; items 只可能是 label / reserve(layout 已把 align 归一化成 reserve)。
;; 出现别的说明 layout 和 encode 对"这段是不是洞"的理解不一致, 直接报错。
(define (encode-hole-segment seg)
  (define name (segment-field seg 'name))
  (define size (segment-field seg 'size))
  (define cursor 0)                 ; 已推进的内存偏移: 这里没有文件偏移
  (for ([entry (in-list (segment-items seg))])
    (define at (cadr entry))
    (define it (caddr entry))
    (check-offset! name at cursor it)
    (cond
      [(label-form? it) (void)]
      [(reserve-form? it) (set! cursor (+ cursor (reserve-size it)))]
      [else (error 'encode
                   "hole 段 ~a 里出现了要写字节的 item(洞的内容不归本产物定义): ~e"
                   name it)]))
  (unless (= cursor size)
    (error 'encode "段 ~a 的尺寸不一致: 产物说 ~a, 位置只推进了 ~a" name size cursor))
  (list 'segment
        (list 'name name)
        (list 'kind 'hole)
        (list 'start (segment-field seg 'start))
        (list 'size size)
        (list 'bytes #"")))

(define (encode-materialized-segment target seg symbols)
  (define name (segment-field seg 'name))
  (define kind (segment-field seg 'kind))
  (define start (segment-field seg 'start))
  (define size (segment-field seg 'size))
  (define entries (segment-items seg))

  (define chunks '())                     ; 逆序的 byte list
  (define cursor 0)
  (define (emit! bs)
    (set! chunks (cons bs chunks))
    (set! cursor (+ cursor (length bs))))

  (for ([entry (in-list entries)])
    (define at (cadr entry))
    (define it (caddr entry))
    (define here (+ start at))
    (check-offset! name at cursor it)
    (cond
      [(label-form? it) (void)]
      ;; (pad n): layout 已经把"对齐请求"换算成"要补多少个字节"
      [(pad-form? it)
       (emit! (padding-bytes target kind (cadr it)))]
      [(bytes-form? it) (emit! (cdr it))]
      [(fill-form? it) (emit! (make-list (cadr it) (caddr it)))]
      [(value-form? it) (emit! (value->bytes (value-width it) (value-payload it) symbols))]
      [else (encode-code target it here symbols emit!)]))

  (unless (= cursor size)
    (error 'encode "段 ~a 的尺寸不一致: 产物说 ~a, 实际写了 ~a 字节" name size cursor))

  ;; 最终产物的段和布局产物同一个形状家族, 只是把 items 换成 bytes;
  ;; kind 要留着 —— loader 靠它决定可执行还是可写。
  (list 'segment
        (list 'name name)
        (list 'kind kind)
        (list 'start start)
        (list 'size size)
        (list 'bytes (list->bytes (append* (reverse chunks))))))

;; 两种段两种写法: 材料化的逐条落字节; hole 只推进位置。
;; 没有第三个分支 —— "洞从哪儿开始" 不作为状态存在, 它由段的 kind 声明。
(define (encode-segment target seg symbols)
  (if (eq? (segment-field seg 'kind) 'hole)
      (encode-hole-segment seg)
      (encode-materialized-segment target seg symbols)))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (encode-layout target layout)
  (unless (eq? (layout-phase layout) 'bound)
    (error 'encode
           "需要 bind-labels 之后的 bound-layout；先跑 bind-labels（当前 phase: ~e）"
           (layout-phase layout)))
  (define problems (layout-problems layout))
  (define requests (layout-requests layout))
  (when (or (pair? problems) (pair? requests))
    (error 'encode "layout 还有未解决的 requests/problems, 拒绝出产物:~%~a"
           (string-join
            (for/list ([p (in-list (append requests problems))])
              (format "  ~s" p))
            "\n")))
  (define symbols (layout-symbols layout))
  ;; link / provides 原样搬运: 它们是 bind-labels 已经算好的, 本层不重算。
  (define link (layout-link layout))
  (define provides (layout-provides layout))
  (unless link
    (error 'encode "bound-layout 里没有 link 表: ~e" (map car layout)))
  (unless provides
    (error 'encode "bound-layout 里没有 provides: ~e" (map car layout)))
  (list* 'build
         (cons 'link link)
         (cons 'provides provides)
         (for/list ([seg (in-list (layout-segments layout))])
           (encode-segment target seg symbols))))
