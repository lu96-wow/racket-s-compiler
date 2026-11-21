#lang racket
;;; raw/raw.rkt
;;;
;;; raw 纯汇编单元的形状校验和规范化。
;;;
;;; 输入：(raw chain item ...)
;;; 输出：raw-layout
;;;   name / items / size / labels
;;;
;;; 第一版只做封闭单元内的 label 解析和固定 4 字节形式：
;;;   - 不展开 li / la / 远跳；
;;;   - 不允许跨 raw 的控制转移；
;;;   - 所有非 label item 都是 4 字节。

(require racket/list
         "../core/sexp.rkt"
         "../ir/shape.rkt"
         "../asm/insn.rkt")

(provide (struct-out raw-layout)
         raw-form?
         raw-name
         layout-raw)

(struct raw-layout
  (name
   items   ; 已经换成 encode 可接受的 flat item
   size
   labels) ; hash 全局链 -> 段内偏移
  #:transparent)

(define (raw-form? x)
  (and (tagged? x 'raw)
       (>= (length x) 2)
       (chain? (cadr x))))

(define (raw-name form)
  (unless (raw-form? form)
    (error 'raw "malformed raw: ~e" form))
  (cadr form))

(define (raw-items form)
  (unless (raw-form? form)
    (error 'raw "malformed raw: ~e" form))
  (cddr form))

(define (label-item? x)
  (and (form? x)
       (eq? (car x) 'label)
       (pair? (cdr x))
       (andmap chain? (cdr x))))

(define (layout-raw form)
  (unless (raw-form? form)
    (error 'raw "malformed raw: ~e" form))
  (define name (raw-name form))
  (define labels (make-hash))
  (define targets '())
  (define size 0)
  (define out '())

  (define (add-label! chain offset item)
    (when (hash-has-key? labels chain)
      (error 'raw "raw label ~a is defined twice" (chain->string chain)))
    (hash-set! labels chain offset)
    (set! out (append out (list (list 'label chain)))))

  ;; raw 名字在偏移 0 处隐式定义入口 label。
  (add-label! name 0 form)

  (for ([item (in-list (raw-items form))])
    (cond
      [(label-item? item)
       (for ([chain (in-list (cdr item))])
         (add-label! chain size item))]

      [(and (form? item) (eq? (car item) 'j))
       (unless (and (= 2 (length item)) (chain? (cadr item)))
         (error 'raw "malformed j: ~e" item))
       (set! targets (cons (cadr item) targets))
       (set! out (append out (list (list 'jal '(native x0) (cadr item)))))
       (set! size (+ size 4))]

      [(and (form? item) (memq (car item) branch-mnemonics))
       (unless (and (= 4 (length item))
                    (chain? (cadr item))
                    (machine-operand? (caddr item))
                    (machine-operand? (cadddr item)))
         (error 'raw "malformed raw branch: ~e" item))
       (set! targets (cons (cadr item) targets))
       (set! out (append out (list item)))
       (set! size (+ size 4))]

      [(and (form? item) (eq? (car item) 'jal))
       (unless (and (= 3 (length item))
                    (physical-register? (cadr item))
                    (chain? (caddr item)))
         (error 'raw "malformed raw jal: ~e" item))
       (set! targets (cons (caddr item) targets))
       (set! out (append out (list item)))
       (set! size (+ size 4))]

      [else
       (unless (and (form? item) (symbol? (car item)))
         (error 'raw "raw item must be a non-empty proper list: ~e" item))
       (when (memq (car item) '(label call-target term frame scratch allocation
                                global native frame-slot slot))
         (error 'raw "raw item uses a forbidden head: ~e" item))
       (unless (andmap machine-operand? (cdr item))
         (error 'raw
                "raw native operands must be integers or (native xN): ~e"
                item))
       (set! out (append out (list item)))
       (set! size (+ size 4))]))

  (for ([target (in-list targets)])
    (unless (hash-has-key? labels target)
      (error 'raw "raw branch target ~a is not in the same raw unit"
             (chain->string target))))

  (raw-layout name out size labels))
