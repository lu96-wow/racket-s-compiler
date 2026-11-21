#lang racket
;;; ir/allocate.rkt
;;;
;;; 第一版真实分配：liveness -> 干涉图 -> 着色 -> spill 到 slot。
;;;
;;; 输入：已验证的 virtual func。
;;; 输出：
;;;   (values allocation scratch)
;;;
;;; 约定：
;;;   - x0 永远不分配；
;;;   - (address-taken) vreg 必须落 slot；
;;;   - pin 固定到物理寄存器；
;;;   - reserve / clobber / #:forbidden 的寄存器不分配给普通 vreg；
;;;   - scratch 从可用寄存器里预留，普通 vreg 不能占用；
;;;   - 没有可用寄存器时 spill 到唯一 slot；
;;;   - 不生成 prologue / epilogue，不做 ABI。
;;;
;;; 这不是最优分配：没有 coalescing，也没有 slot sharing。
;;; 但它尊重所有现有约束，输出可以直接交给 verify-allocation / materialize。

(require racket/list
         "../core/sexp.rkt"
         "shape.rkt"
         "analysis.rkt"
         "allocation.rkt"
         "liveness.rkt"
         "scratch.rkt"
         "verify.rkt")

(provide allocate-func
         default-allocatable-registers)

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (allocate-func func
                       #:scratch-budget [scratch-budget 0]
                       #:forbidden [forbidden '()])
  (unless (and (tagged? func 'func) (>= (length func) 2))
    (error 'allocate "expected a func: ~e" func))
  (unless (and (exact-nonnegative-integer? scratch-budget))
    (error 'allocate "scratch budget must be a non-negative integer: ~e"
           scratch-budget))
  (unless (and (list? forbidden) (andmap physical-register? forbidden))
    (error 'allocate "forbidden registers must be (native xN): ~e" forbidden))

  ;; 形状、声明、pin/reserve/address-taken 约束先走一遍 verify。
  (verify-virtual-func func)

  (define relevant (relevant-vregs func))
  (define address-taken
    (for/hash ([decl (in-list (func-vreg-decls func))]
               #:when (vreg-decl-address-taken? decl))
      (values (car decl) #t)))
  (define lv (analyze-liveness func))
  (define graph (build-interference-graph relevant lv))
  (define pins (func-pins func))
  (define reserved (func-reserved func))
  (define clobbered (func-clobbered func))
  (for ([(reg _) (in-hash (func-asm-clobbered func))])
    (hash-set! clobbered reg #t))
  (define forbidden-set (make-hash))
  (for ([reg (in-list forbidden)]) (hash-set! forbidden-set reg #t))
  ;; x0 是零寄存器，不能被普通 vreg 或 scratch 使用。
  (hash-set! forbidden-set '(native x0) #t)

  ;; pin 不能是 x0；同一个 pin 寄存器被两个互相干涉的 vreg 使用也不行。
  (for ([(vreg reg) (in-hash pins)])
    (when (equal? reg '(native x0))
      (error 'allocate "vreg ~a cannot be pinned to x0"
             (vreg->string vreg)))
    (for ([neighbor (in-list (graph-neighbors graph vreg))])
      (define other-pin (hash-ref pins neighbor #f))
      (when (and other-pin (equal? other-pin reg))
        (error 'allocate
               "vregs ~a and ~a are pinned to ~e but interfere"
               (vreg->string vreg) (vreg->string neighbor) reg))))

  ;; scratch 从没有被 pin / reserve / clobber / forbidden 占用的寄存器里选。
  (define pinned-regs
    (for/hash ([(vreg reg) (in-hash pins)]) (values reg #t)))
  (define scratch-pool
    (filter (lambda (reg)
              (and (not (hash-has-key? pinned-regs reg))
                   (not (hash-has-key? reserved reg))
                   (not (hash-has-key? clobbered reg))
                   (not (hash-has-key? forbidden-set reg))))
            (default-allocatable-registers)))
  (when (< (length scratch-pool) scratch-budget)
    (error 'allocate
           "not enough registers for scratch budget ~a (available: ~a)"
           scratch-budget (length scratch-pool)))
  (define scratch-regs (take scratch-pool scratch-budget))

  ;; 普通 vreg 的可用寄存器：排除 scratch 和所有不可用集合。
  (define scratch-set
    (for/hash ([reg (in-list scratch-regs)]) (values reg #t)))
  (define allocatable
    (filter (lambda (reg)
              (and (not (hash-has-key? scratch-set reg))
                   (not (hash-has-key? reserved reg))
                   (not (hash-has-key? clobbered reg))
                   (not (hash-has-key? forbidden-set reg))))
            (default-allocatable-registers)))

  (define colors (assign-colors relevant graph pins allocatable address-taken))
  (define entries (assign-locations relevant colors address-taken))

  (define allocation (cons 'allocation entries))
  (define scratch (cons 'scratch scratch-regs))

  ;; 自检：输出必须直接通过 allocation 约束。
  (verify-allocation func allocation scratch)
  (values allocation scratch))

;; ---------------------------------------------------------------------------
;; relevant vregs
;; ---------------------------------------------------------------------------

;; 声明顺序；只包含代码里用到的 vreg 和 address-taken 的 vreg。
(define (relevant-vregs func)
  (define used
    (for/hash ([vreg (in-list (func-used-vregs func))]) (values vreg #t)))
  (for/list ([decl (in-list (func-vreg-decls func))]
             #:when (or (hash-has-key? used (car decl))
                        (vreg-decl-address-taken? decl)))
    (car decl)))

;; ---------------------------------------------------------------------------
;; interference graph
;; ---------------------------------------------------------------------------

(define (build-interference-graph relevant lv)
  (define graph (make-hash))
  (for ([vreg (in-list relevant)])
    (hash-set! graph vreg (make-hash)))

  (define (add-edge! a b)
    (unless (equal? a b)
      (hash-set! (hash-ref graph a) b #t)
      (hash-set! (hash-ref graph b) a #t)))

  (for ([block (in-hash-keys (liveness-instructions lv))])
    (for ([ins (in-list (hash-ref (liveness-instructions lv) block))])
      ;; 在指令边界上同时 live 的值都互相干涉。
      ;; 这样即使某个 vreg 没有显式定义（例如从外部传入的初值），也不会被分配到同一个寄存器。
      (define live
        (set-union (instruction-live-before ins)
                   (instruction-live-after ins)))
      (define vs (set->list live))
      (for ([a (in-list vs)]
            [i (in-naturals)])
        (for ([b (in-list (drop vs (add1 i)))])
          (add-edge! a b)))))

  graph)

(define (graph-neighbors graph vreg)
  (define neighbors (hash-ref graph vreg #f))
  (if neighbors (hash-keys neighbors) '()))

(define (graph-degree graph vreg)
  (length (graph-neighbors graph vreg)))

;; ---------------------------------------------------------------------------
;; coloring
;; ---------------------------------------------------------------------------

(define (assign-colors relevant graph pins allocatable address-taken)
  (define colors (make-hash))

  ;; pin 先固定。
  (for ([vreg (in-list relevant)])
    (define reg (hash-ref pins vreg #f))
    (when reg (hash-set! colors vreg reg)))

  ;; 其余 vreg 按度数降序、声明顺序升序着色。
  (define order
    (sort (filter (lambda (vreg)
                    (and (not (hash-has-key? pins vreg))
                         (not (hash-has-key? address-taken vreg))))
                  relevant)
          (lambda (a b)
            (define da (graph-degree graph a))
            (define db (graph-degree graph b))
            (if (= da db)
                (< (vreg-index a relevant) (vreg-index b relevant))
                (> da db)))))

  (for ([vreg (in-list order)])
    (define used
      (for/hash ([neighbor (in-list (graph-neighbors graph vreg))])
        (define color (hash-ref colors neighbor #f))
        (values neighbor color)))
    (define used-regs
      (for/hash ([(neighbor color) (in-hash used)]
                 #:when (physical-register? color))
        (values color #t)))
    (define choice
      (findf (lambda (reg) (not (hash-has-key? used-regs reg))) allocatable))
    (when choice
      (hash-set! colors vreg choice)))

  colors)

;; ---------------------------------------------------------------------------
;; locations
;; ---------------------------------------------------------------------------

(define (assign-locations relevant colors address-taken)
  (define next-slot 0)
  (for/list ([vreg (in-list relevant)])
    (define location
      (cond
        [(hash-has-key? address-taken vreg)
         (begin0 (list 'slot next-slot)
           (set! next-slot (add1 next-slot)))]
        [(hash-ref colors vreg #f)
         (hash-ref colors vreg)]
        [else
         (begin0 (list 'slot next-slot)
           (set! next-slot (add1 next-slot)))]))
    (list vreg location)))

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (default-allocatable-registers)
  (for/list ([i (in-range 1 32)])
    (list 'native (string->symbol (format "x~a" i)))))

(define (vreg-index vreg relevant)
  (let loop ([lst relevant] [i 0])
    (cond
      [(null? lst) i]
      [(equal? (car lst) vreg) i]
      [else (loop (cdr lst) (add1 i))])))

(define (vreg->string vreg)
  (format "($ ~a)" (cadr vreg)))
