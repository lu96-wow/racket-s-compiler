#lang racket
;;; ir/frame.rkt
;;;
;;; frame-layout：把 allocation 里的 slot 和 vreg 类型变成 frame 偏移。
;;;
;;; 第一版 stack-first 约定：
;;;   - FP 指向调用者的 SP（当前帧高地址边界）；
;;;   - frame 向下增长；
;;;   - header 默认 16 字节：saved RA + saved old FP；
;;;   - slot offset 是 FP 到 slot 低地址的距离，即地址 = FP - offset；
;;;   - outgoing args 在帧底部，靠近 SP；
;;;   - 整个 frame 16 字节对齐。
;;;
;;; 这里不做 prologue/epilogue，不做 stack map，不选寄存器。

(require "../core/sexp.rkt"
         "../core/num.rkt"
         "shape.rkt"
         "analysis.rkt"
         "allocation.rkt")

(provide frame-form?
         frame-layout
         frame-size
         frame-outgoing
         frame-slots
         frame-slot-offset)

;; (frame
;;   (size n)
;;   (header n)
;;   (outgoing n)
;;   (align n)
;;   (slots
;;     (slot 0 (offset o) (size s) (align a))
;;     ...))
(define (frame-slot-entry? x)
  (match x
    [(list 'slot
           (? exact-nonnegative-integer?)
           (list 'offset (? exact-nonnegative-integer?))
           (list 'size (? exact-positive-integer?))
           (list 'align (? exact-positive-integer?)))
     #t]
    [_ #f]))

(define (frame-form? x)
  (and (tagged? x 'frame)
       (match (cdr x)
         [(list (list 'size (? exact-nonnegative-integer?))
                (list 'header (? exact-nonnegative-integer?))
                (list 'outgoing (? exact-nonnegative-integer?))
                (list 'align (? exact-positive-integer?))
                (list 'slots slots ...))
          (andmap frame-slot-entry? slots)]
         [_ #f])))

(define (frame-clause frame key)
  (assoc key (cdr frame)))

(define (frame-size frame)
  (cadr (frame-clause frame 'size)))

(define (frame-outgoing frame)
  (cadr (frame-clause frame 'outgoing)))

(define (frame-slots frame)
  (define clause (frame-clause frame 'slots))
  (if clause (cdr clause) '()))

;; slot index -> FP 到 slot 低地址的距离；找不到返回 #f。
(define (frame-slot-offset frame slot-index)
  (define hit
    (findf (lambda (slot)
             (and (form? slot)
                  (eq? (car slot) 'slot)
                  (= (cadr slot) slot-index)))
           (frame-slots frame)))
  (and hit
       (cadr (assoc 'offset (cddr hit)))))

;; ---------------------------------------------------------------------------
;; 布局
;; ---------------------------------------------------------------------------

(define (frame-layout func allocation
                      #:xlen [xlen 64]
                      #:header-size [header-size 16]
                      #:outgoing-size [outgoing-size 0]
                      #:frame-align [frame-align 16])
  (unless (and (exact-positive-integer? xlen)
               (zero? (modulo xlen 8)))
    (error 'frame-layout "xlen must be a positive multiple of 8: ~e" xlen))
  (unless (and (exact-nonnegative-integer? header-size)
               (exact-nonnegative-integer? outgoing-size))
    (error 'frame-layout "header/outgoing size must be non-negative integers"))
  (unless (and (exact-positive-integer? frame-align)
               (zero? (bitwise-and frame-align (sub1 frame-align))))
    (error 'frame-layout "frame alignment must be a power of two: ~e" frame-align))
  (unless (allocation-form? allocation)
    (error 'frame-layout "malformed allocation: ~e" allocation))

  (define decls (func-vreg-table func))
  (define entries (cdr allocation))

  ;; address-taken 必须在 stack slot；这是 frame 层依赖的分配约束。
  (for ([decl (in-list (func-vreg-decls func))])
    (when (vreg-decl-address-taken? decl)
      (define vreg (car decl))
      (define location (allocation-location allocation vreg))
      (unless (and location (slot-location? location))
        (error 'frame-layout
               "address-taken vreg ~a must be allocated to a slot, got: ~e"
               (vreg->string vreg) location))))

  ;; slot index -> (list size align)，多个 vreg 共享 slot 时取最大。
  (define slot-info (make-hash))
  (for ([entry (in-list entries)])
    (define vreg (car entry))
    (define location (cadr entry))
    (when (slot-location? location)
      (define slot-index (cadr location))
      (define decl (hash-ref decls vreg #f))
      (unless decl
        (error 'frame-layout
               "allocation slot refers to undeclared vreg ~a"
               (vreg->string vreg)))
      (define-values (size align)
        (decl-size-align decl xlen))
      (define previous (hash-ref slot-info slot-index #f))
      (define merged
        (if previous
            (list (max size (car previous))
                  (max align (cadr previous)))
            (list size align)))
      (hash-set! slot-info slot-index merged)))

  (define slot-indices
    (sort (hash-keys slot-info) <))

  (define cursor header-size)
  (define slot-forms
    (for/list ([slot-index (in-list slot-indices)])
      (define info (hash-ref slot-info slot-index))
      (define size (car info))
      (define align (cadr info))
      (set! cursor (align-up cursor align))
      (set! cursor (+ cursor size))
      (list 'slot slot-index
            (list 'offset cursor)
            (list 'size size)
            (list 'align align))))

  (define total (align-up (+ cursor outgoing-size) frame-align))

  (list 'frame
        (list 'size total)
        (list 'header header-size)
        (list 'outgoing outgoing-size)
        (list 'align frame-align)
        (cons 'slots slot-forms)))

;; ---------------------------------------------------------------------------
;; 类型 -> size / align
;; ---------------------------------------------------------------------------

(define (decl-size-align decl xlen)
  (define-values (size align)
    (type-size-align (vreg-decl-type decl) xlen))
  (define option-align
    (for/fold ([a align]) ([option (in-list (vreg-decl-options decl))])
      (match option
        [(list 'align (? exact-positive-integer? n)) (max a n)]
        [_ a])))
  (values size option-align))

(define (type-size-align type xlen)
  (match type
    [(list 'b8) (values 1 1)]
    [(list 's8) (values 1 1)]
    [(list 'b16) (values 2 2)]
    [(list 's16) (values 2 2)]
    [(list 'b32) (values 4 4)]
    [(list 's32) (values 4 4)]
    [(list 'b64) (values 8 8)]
    [(list 'ptr)
     (define width (quotient xlen 8))
     (values width width)]
    [_ (error 'frame-layout "unsupported type: ~e" type)]))

(define (vreg->string vreg)
  (format "($ ~a)" (cadr vreg)))
