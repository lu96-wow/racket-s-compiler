#lang racket
;;; encode/encode.rkt
;;;
;;; 最后一步: layout -> (build ...)，每个段一坨字节。
;;;
;;; 输入是 relax 之后的 layout:
;;;   ((segments (segment (name s) (kind code) (start x) (end y) (align n)
;;;                       (items (offset k item) ...) (size n)) ...)
;;;    (symbols (symbol 链 段名 偏移 绝对地址) ...)
;;;    (problems))
;;;
;;; 每条 item 怎么落成字节:
;;;   label     不占字节
;;;   pad n     补 n 字节: code 段填合法指令(nop / c.nop), 其余填 0
;;;   bytes     原样
;;;   fill n b  n 个 b
;;;   value w v w 字节, 端序由 target.rkt 定; v 是整数或 (label+ 链 加数)
;;;   真指令    riscv-asm 编码; 目标地址 = 符号表 + 加数, 分支/跳转取相对偏移
;;;   远形式 / li / la   先由 riscv-help 展开成几条真指令, 再逐条编码
;;;
;;; (offset k ...) 是**断言**: 写出去的字节数必须正好让它落在 k。
;;; 不符说明 layout 和 encode 对尺寸的理解不一致, 直接报错(这是抓这类 bug 的地方)。

(require "../layout/layout.rkt"
         "../layout/forms.rkt"
         (only-in "../../riscv-help/main.rkt"
                  branch-long jump-jal jump-auipc-jalr zero-register?
                  li load-pcrel)
         (only-in "../../riscv-asm/base/register.rkt" register->number register-abi-name)
         "../target.rkt"
         "insn.rkt")

(provide encode-layout)

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (segment-field seg key) (cadr (assoc key (cdr seg))))
(define (segment-items seg) (cdr (assoc 'items (cdr seg))))

;; 符号行是 (symbol 链 段名 偏移 绝对地址); 查找/取地址复用 layout 的实现
(define (resolve-symbol symbols chain addend)
  (define row (symbol-row symbols chain))
  (unless row (error 'encode "undefined symbol: ~s" chain))
  (+ (symbol-address row) addend))

(define (value->bytes w v symbols)
  (define n
    (cond
      [(exact-integer? v) v]
      [(label-expr? v) (resolve-symbol symbols (label-expr-chain v) (label-expr-addend v))]
      [else (error 'encode "bad value: ~e" v)]))
  (integer->bytes w n))

;; 操作数: 寄存器名/立即数原样交给 insn.rkt;
;; 控制转移的最后一项是链 -> 换成相对当前 item 的偏移。
(define (operands-at it here symbols)
  (cond
    [(control-form? it)
     (define target (normalize-path (control-target it)))
     (append (drop-right (cdr it) 1)
             (list (- (resolve-symbol symbols target 0) here)))]
    [else (cdr it)]))

;; ---------------------------------------------------------------------------
;; 远形式: 交给 riscv-help 展开成真指令
;; ---------------------------------------------------------------------------

;; riscv-help 的 jump-auipc-jalr 用 (eq? link 'zero) 判断"link 是不是零寄存器"，
;; 直接传数字 0 会走错分支、生成 (auipc x0 …)(jalr x0 x0 …) —— 静默跳到小地址。
;; 所以进 riscv-help 之前统一换成 ABI 名(0 -> 'zero)。等它改成 zero-register? 就能删掉。
(define (abi-name r) (or (register-abi-name r) r))

(define (branch-distance it here symbols index)
  (define target (normalize-path (list-ref it index)))
  (- (resolve-symbol symbols target 0) here))

;; (branch-far cond rs1 rs2 L) = 反向条件分支 + jal
(define (encode-far-branch it here symbols)
  (define cond (cadr it))
  (define d (branch-distance it here symbols 4))
  (branch-long cond
               (register->number (caddr it))
               (register->number (cadddr it))
               d
               (lambda (offset) (jump-jal 'zero offset))))

;; (branch-indirect s cond rs1 rs2 L) = 反向条件分支 + auipc+jalr
(define (encode-indirect-branch it here symbols)
  (define s (cadr it))
  (define cond (caddr it))
  (define d (branch-distance it here symbols 5))
  (branch-long cond
               (register->number (cadddr it))
               (register->number (list-ref it 4))
               d
               (lambda (offset) (jump-auipc-jalr 'zero offset #:scratch (list s)))))

;; (jump-far link [s] L): link 非零时它自己就是 auipc 的落点
(define (encode-far-jump it here symbols)
  (define link (cadr it))
  (define hole? (= 3 (length it)))
  (define target (normalize-path (last it)))
  (define d (- (resolve-symbol symbols target 0) here))
  (cond
    [hole? (error 'encode "(jump-far ~a …) 的空槽没人填, 不能编码" link)]
    [(zero-register? link)
     (jump-auipc-jalr 'zero d #:scratch (list (caddr it)))]
    [else (jump-auipc-jalr (abi-name link) d)]))

;; 一条代码 item 可能展开成几条真指令, 逐条交给 emit! 写出去。
;;   plain  : 操作数里可能有链, 先换成偏移
;;   远形式 / li / la : riscv-help 已经给出带数字偏移的真指令
(define (encode-code it here symbols emit!)
  (define (emit-instruction! name operands)
    (define-values (word n) (encode-instruction name operands))
    (emit! (integer->bytes n word)))
  (define (emit-all! insns)
    (for ([i (in-list insns)]) (emit-instruction! (car i) (cdr i))))
  (case (car it)
    [(branch-far)      (emit-all! (encode-far-branch it here symbols))]
    [(branch-indirect) (emit-all! (encode-indirect-branch it here symbols))]
    [(jump-far)        (emit-all! (encode-far-jump it here symbols))]
    ;; (li rd 常量): 尺寸由 layout 用 li-size 精确算过, 这里用同一个展开器
    [(li) (emit-all! (li (cadr it) (caddr it)))]
    ;; (la rd [tmp] 链): 近形式 8 字节; layout 已经保证够得着, 所以不需要 scratch
    [(la) (define d (- (resolve-symbol symbols (normalize-path (last it)) 0) here))
          (emit-all! (load-pcrel (cadr it) d))]
    [else (emit-instruction! (car it) (operands-at it here symbols))]))

;; ---------------------------------------------------------------------------
;; 段
;; ---------------------------------------------------------------------------

(define (encode-segment seg symbols)
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
    (unless (= at cursor)
      (error 'encode
             "段 ~a 的偏移不一致: layout 说 ~a, encode 算到 ~a (item ~e)"
             name at cursor it))
    (cond
      [(label-form? it) (void)]
      ;; (pad n): layout 已经把"对齐请求"换算成"要补多少个字节"
      [(pad-form? it)
       (emit! (padding-bytes kind (cadr it)))]
      [(bytes-form? it) (emit! (cdr it))]
      [(fill-form? it) (emit! (make-list (cadr it) (caddr it)))]
      [(value-form? it) (emit! (value->bytes (value-width it) (value-payload it) symbols))]
      [else (encode-code it here symbols emit!)]))

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

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (encode-layout layout)
  (define problems (layout-problems layout))
  (when (pair? problems)
    (error 'encode "layout 还有未解决的问题, 拒绝出产物:~%~a"
           (string-join (for/list ([p (in-list problems)]) (format "  ~s" p)) "\n")))
  (define symbols (cdr (assoc 'symbols layout)))
  (cons 'build
        (for/list ([seg (in-list (cdr (assoc 'segments layout)))])
          (encode-segment seg symbols))))
