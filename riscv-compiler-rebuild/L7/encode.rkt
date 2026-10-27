#lang racket
;;; L7/encode.rkt
;;;
;;; 最后一步: layout -> (build ...)，每个段一坨字节。
;;;
;;; 输入是 L6 之后的 layout:
;;;   ((segments (segment (name s) (kind code) (start x) (end y) (align n)
;;;                       (items (offset k item) ...) (size n)) ...)
;;;    (symbols (链 段 偏移 绝对地址) ...)
;;;    (problems ...))
;;;
;;; 规则:
;;;   label            -> 不占字节
;;;   align n          -> 补到**绝对地址**对齐; code 段补 nop(会顺着执行), 其余补 0
;;;   bytes            -> 原样
;;;   fill n b         -> n 个 b
;;;   value w 值       -> w 字节, 端序由 target.rkt 定; 值可以是整数或 (label+ 链 加数)
;;;   真指令           -> riscv-asm 编码; 目标地址 = 符号表 + 加数, 分支/跳转取相对偏移
;;;   远形式           -> riscv-help 展开成几条真指令再编码
;;;
;;; 每个 item 的 (offset k ...) 是**断言**: 写出去的字节数必须正好让它落在 k。
;;; 不符说明 L5 和 L7 对尺寸的理解不一致, 直接报错(这是抓这类 bug 的地方)。
;;;
;;; li / la 还没做(尺寸契约未定), 见到就报错。

(require "../L5/layout.rkt"
         "../L5/forms.rkt"
         (only-in "../../riscv-help/main.rkt"
                  branch-long jump-jal jump-auipc-jalr zero-register?)
         (only-in "../../riscv-asm/base/register.rkt" register->number register-abi-name)
         "target.rkt"
         "insn.rkt")

(provide encode-layout)

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (segment-field seg key) (cadr (assoc key (cdr seg))))
(define (segment-items seg) (cdr (assoc 'items (cdr seg))))

(define (symbol-address symbols chain addend)
  (define row (assoc chain symbols))
  (unless row
    (error 'encode "undefined symbol: ~s" chain))
  (+ (cadddr row) addend))

(define (padding-bytes kind n)
  (if (eq? kind 'code) (code-padding-bytes n) (make-list n 0)))

(define (value->bytes w v symbols)
  (define n
    (cond
      [(exact-integer? v) v]
      [(label-expr? v) (symbol-address symbols (label-expr-chain v) (label-expr-addend v))]
      [else (error 'encode "bad value: ~e" v)]))
  (integer->bytes w n))

;; 操作数: 寄存器名/立即数原样交给 insn.rkt;
;; 控制转移的最后一项是链 -> 换成相对当前 item 的偏移。
(define (operands-at it here symbols)
  (cond
    [(control-form? it)
     (define target (normalize-path (control-target it)))
     (append (drop-right (cdr it) 1)
             (list (- (symbol-address symbols target 0) here)))]
    [else (cdr it)]))

;; ---------------------------------------------------------------------------
;; 远形式: 交给 riscv-help 展开成真指令
;; ---------------------------------------------------------------------------

(define (abi-name r) (or (register-abi-name r) r))

(define (branch-distance it here symbols index)
  (define target (normalize-path (list-ref it index)))
  (- (symbol-address symbols target 0) here))

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
  (define d (- (symbol-address symbols target 0) here))
  (cond
    [hole? (error 'encode "(jump-far ~a …) 的空槽没人填, 不能编码" link)]
    [(zero-register? link)
     (jump-auipc-jalr 'zero d #:scratch (list (caddr it)))]
    [else (jump-auipc-jalr (abi-name link) d)]))

;; 一条真指令 -> (cons 字 字节数)
(define (encode-one name operands)
  (define-values (word n) (encode-instruction name operands))
  (cons word n))

(define (encode-all insns)
  (for/list ([i (in-list insns)]) (encode-one (car i) (cdr i))))

;; 一条代码 item -> (listof (cons 字 字节数))
;;   plain: 操作数里可能有链, 先换成偏移
;;   远形式: riscv-help 已经给出带数字偏移的真指令
(define (encode-code it here symbols)
  (cond
    [(eq? (car it) 'branch-far)      (encode-all (encode-far-branch it here symbols))]
    [(eq? (car it) 'branch-indirect) (encode-all (encode-indirect-branch it here symbols))]
    [(eq? (car it) 'jump-far)        (encode-all (encode-far-jump it here symbols))]
    [(memq (car it) '(li la)) (error 'encode "~a 还没实现(L7 Phase 2)" (car it))]
    [else (list (encode-one (car it) (operands-at it here symbols)))]))

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
             "段 ~a 的偏移不一致: L5 说 ~a, L7 算到 ~a (item ~e)"
             name at cursor it))
    (cond
      [(label-form? it) (void)]
      [(align-form? it)
       (define n (cadr it))
       (emit! (padding-bytes kind (modulo (- n (modulo here n)) n)))]
      [(bytes-form? it) (emit! (cdr it))]
      [(fill-form? it) (emit! (make-list (cadr it) (caddr it)))]
      [(value-form? it) (emit! (value->bytes (value-width it) (value-payload it) symbols))]
      [else
       (for ([e (in-list (encode-code it here symbols))])
         (emit! (integer->bytes (cdr e) (car e))))]))

  (unless (= cursor size)
    (error 'encode "段 ~a 的尺寸不一致: 产物说 ~a, 实际写了 ~a 字节" name size cursor))

  (list 'segment
        (list 'name name)
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
