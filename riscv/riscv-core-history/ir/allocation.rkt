#lang racket
;;; ir/allocation.rkt
;;;
;;; Step 3：allocation 是一张映射表，不是代码。
;;;
;;; 形状：
;;;   (allocation (vreg location) ...)
;;;   location := (native xN) | (slot n)
;;;   scratch  := (scratch (native xN))          ; 单独返回，不进表
;;;
;;; 这一层只检查：
;;;   - 条目是二元 proper list；
;;;   - key 是已声明 vreg，location 合法；
;;;   - 没有重复 key；
;;;   - 被使用的 vreg / address-taken vreg 有条目；
;;;   - address-taken vreg 落在 slot；
;;;   - pin / reserve 约束没有被违反。
;;;
;;; 它不生成 allocation，不做 materialize。

(require racket/list
         "../core/sexp.rkt"
         "shape.rkt"
         "analysis.rkt"
         "scratch.rkt")

(provide allocation-form?
         allocation-entry?
         location?
         slot-location?
         scratch-form?
         scratch-registers
         allocation-table
         allocation-location
         verify-allocation)

;; (slot n)
(define (slot-location? x)
  (match x
    [(list 'slot (? exact-nonnegative-integer?)) #t]
    [_ #f]))

(define (location? x)
  (or (physical-register? x)
      (slot-location? x)))

;; (vreg location)
(define (allocation-entry? x)
  (match x
    [(list (? vreg? _) (? location?)) #t]
    [_ #f]))

(define (allocation-form? x)
  (and (tagged? x 'allocation)
       (andmap allocation-entry? (cdr x))))

;; 便利函数：把表变成 hash；调用方应先用 verify-allocation。
(define (allocation-table allocation)
  (for/hash ([entry (in-list (cdr allocation))])
    (values (car entry) (cadr entry))))

;; 按文档的 list 操作查位置；不存在的 vreg 返回 #f。
(define (allocation-location allocation vreg)
  (define hit (assoc vreg (cdr allocation)))
  (and hit (cadr hit)))

;; ---------------------------------------------------------------------------
;; 验证
;; ---------------------------------------------------------------------------

;; scratch 可选：不传则不检查，传了就必须是 (scratch (native xN))。
(define (verify-allocation func allocation [scratch #f])
  (unless (allocation-form? allocation)
    (error 'verify-allocation "malformed allocation: ~e" allocation))
  (when scratch
    (unless (scratch-form? scratch)
      (error 'verify-allocation "malformed scratch: ~e" scratch))
    (check-scratch-unique! (cdr scratch) 'verify-allocation))

  (define decls (func-vreg-table func))
  (define used (func-used-vregs func))
  (define address-taken
    (for/list ([decl (in-list (func-vreg-decls func))]
               #:when (vreg-decl-address-taken? decl))
      (car decl)))

  (define table (make-hash))
  (for ([entry (in-list (cdr allocation))])
    (define vreg (car entry))
    (define location (cadr entry))
    (unless (hash-has-key? decls vreg)
      (error 'verify-allocation
             "allocation entry refers to undeclared vreg ~a"
             (vreg->string vreg)))
    (when (hash-has-key? table vreg)
      (error 'verify-allocation
             "vreg ~a has more than one allocation entry"
             (vreg->string vreg)))
    (hash-set! table vreg location))

  ;; 被使用的 vreg 必须有位置。
  (for ([vreg (in-list used)])
    (unless (hash-has-key? table vreg)
      (error 'verify-allocation
             "used vreg ~a has no allocation entry"
             (vreg->string vreg))))

  ;; address-taken vreg 必须有位置，并且必须是 slot。
  (for ([vreg (in-list address-taken)])
    (define location (hash-ref table vreg #f))
    (unless location
      (error 'verify-allocation
             "address-taken vreg ~a has no allocation entry"
             (vreg->string vreg)))
    (unless (slot-location? location)
      (error 'verify-allocation
             "address-taken vreg ~a must be allocated to (slot n), got: ~e"
             (vreg->string vreg) location)))

  ;; pin：如果分配了，就必须落在指定物理寄存器。
  (for ([(vreg pinned) (in-hash (func-pins func))])
    (define location (hash-ref table vreg #f))
    (when location
      (unless (equal? location pinned)
        (error 'verify-allocation
               "pinned vreg ~a must be allocated to ~e, got: ~e"
               (vreg->string vreg) pinned location))))

  ;; reserve：普通 vreg 不能落进保留寄存器；显式 pin 到该寄存器除外。
  (define reserved (func-reserved func))
  (define pins (func-pins func))
  (for ([(vreg location) (in-hash table)])
    (when (physical-register? location)
      (when (and (hash-has-key? reserved location)
                 (not (equal? (hash-ref pins vreg #f) location)))
        (error 'verify-allocation
               "vreg ~a uses reserved register ~e without a pin"
               (vreg->string vreg) location))))

  allocation)

(define (vreg->string vreg)
  (format "($ ~a)" (cadr vreg)))
