#lang racket
;;; L4/forms.rkt
;;;
;;; 形式表: 每条 item 的字节数、类别、可达距离、是否需要 scratch。
;;; 只放数据 + 查询; 布局计算本身在 layout.rkt。
;;;
;;; 不在表里的助记符: 按 RISC-V 的常识兜底 —— c.* 是 2 字节, 其余 4 字节。
;;; (真指令名单不在本层维护; 编不出来是后面编码层的事)

(provide form? name? path? normalize-path
         label-form? align-form? bytes-form?
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

;; layout 输入的三个子句
(define (items-form? x)   (and (form? x) (eq? (car x) 'items)))
(define (segment-form? x) (and (form? x) (eq? (car x) 'segment)))

(define (segment-kind? k) (memq k '(code data rodata)))

;; ---------------------------------------------------------------------------
;; 分类
;; ---------------------------------------------------------------------------

(define branch-mnemonics   '(beq bne blt bge bltu bgeu branch-far branch-indirect))
(define jump-mnemonics     '(jal jump-far call-far))

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
;;   data   = bytes
;; ---------------------------------------------------------------------------

(define (item-kind x)
  (cond
    [(label-form? x) 'marker]
    [(align-form? x) 'both]
    [(bytes-form? x) 'data]
    [else 'code]))

;; ---------------------------------------------------------------------------
;; 字节数
;; ---------------------------------------------------------------------------

(define (item-size x)
  (cond
    [(label-form? x) 0]
    [(align-form? x) #f]              ; 由游标算
    [(bytes-form? x) (length (cdr x))]
    [(branch-form? x)
     (case (car x)
       [(branch-far) 8]
       [(branch-indirect) 12]
       [else 4])]
    [(jump-form? x)
     (case (car x)
       [(jump-far call-far) 8]
       [else 4])]
    [(eq? (car x) 'la) 8]
    [else
     ;; 兜底: c.* 2 字节, 其余 4 字节
     (if (and (symbol? (car x))
              (string-prefix? (symbol->string (car x)) "c."))
         2
         4)]))

;; ---------------------------------------------------------------------------
;; 可达距离 (字节); #f = 不设限 / 不是控制转移
;; ---------------------------------------------------------------------------

(define (form-range x)
  (cond
    [(branch-form? x)
     (case (car x)
       [(branch-far) 1048576]
       [(branch-indirect) #f]
       [else 4096])]
    [(jump-form? x)
     (case (car x)
       [(jump-far call-far) #f]
       [else 1048576])]
    [else #f]))

;; ---------------------------------------------------------------------------
;; scratch 空槽: 用"参数缺失"表示
;;   (branch-indirect a b L)      => 空槽
;;   (branch-indirect s a b L)    => 已填
;; ---------------------------------------------------------------------------

(define (full-length x)
  (case (car x)
    [(branch-indirect) 5]
    [(jump-far) 3]
    [else #f]))

(define (scratch-hole? x)
  (define n (and (form? x) (full-length x)))
  (and n (= (length x) (sub1 n))))
