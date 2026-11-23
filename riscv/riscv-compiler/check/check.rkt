#lang racket
;;; check/check.rkt
;;;
;;; 显式形式检查: measured-layout -> measured-layout + problems。
;;;
;;; 本层**不改** item / offset / size, 不升形式, 不填 scratch。
;;; 分支 / 跳转 / 地址加载的形式由前端显式选择:
;;;
;;   短形式:   (beq L a b) / (jal rd L) / (j L) / (la-pcrel rd expr)
;;;   显式远形式:
;;;     (branch-jal cond rs1 rs2 L)             ; 反向分支 + jal
;;;     (branch-auipc-jalr tmp cond rs1 rs2 L)  ; 反向分支 + auipc+jalr
;;;     (jump-auipc-jalr link base L)           ; auipc+jalr
;;;     (la-pcrel-li-add rd tmp expr)           ; auipc + li + add
;;;
;;; 本层只回答“前端选的这个形式在这里是否成立”:
;;;   - 目标是否存在
;;;   - 距离是否在该形式的范围内
;;;   - scratch/base/tmp 是否是合法寄存器
;;;   - 近 la-pcrel 是否够得着 (够不着就报错, 让前端改写成 la-pcrel-li-add)
;;;
;;; 所有失败都是 problems, 不是 requests; 没有后续 pass 会替你升形式。

(require racket/list
         "../sexp.rkt"
         "../meta.rkt"
         (only-in "../layout/layout.rkt"
                  layout-phase layout-segments layout-anchors
                  layout-problems layout-externs)
         "../layout/forms.rkt"
         (only-in "../../riscv-asm/base/register.rkt" zero-register? same-register?)
         (only-in "../target.rkt" target-xlen)
         (only-in "../../riscv-help/main.rkt" fits-auipc-pair?))

(provide check-layout)

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (segment-field seg key)
  (tag-ref* 'check seg key #f))

(define (segment-items seg)
  (cdr (assoc 'items (cdr seg))))

(define (set-layout-field layout key value)
  (for/list ([row (in-list layout)])
    (if (and (pair? row) (eq? (car row) key))
        (cons key value)
        row)))

(struct site (seg off item here) #:transparent)

;; ---------------------------------------------------------------------------
;; 位置表: 和 layout 内部用的是同一套公式
;;   anchor 地址 = segment.start + anchor.offset
;;   extern 地址直接来自输入侧 link 表
;; ---------------------------------------------------------------------------

(define (collect-positions layout)
  (define start-of
    (for/hash ([seg (in-list (layout-segments layout))])
      (values (segment-field seg 'name)
              (segment-field seg 'start))))
  (define h (make-hash))
  (for ([a (in-list (layout-anchors layout))])
    (hash-set! h (cadr a)
               (+ (hash-ref start-of (caddr a) 0)
                  (cadddr a))))
  (for ([row (in-list (layout-externs layout))])
    (define addr (caddr row))
    (when addr (hash-set! h (cadr row) addr)))
  h)

;; ---------------------------------------------------------------------------
;; 外部符号自检
;; ---------------------------------------------------------------------------

(define (check-externs layout problem!)
  (define local
    (for/hash ([a (in-list (layout-anchors layout))])
      (values (cadr a) #t)))
  (define unlinked '())
  (for ([row (in-list (layout-externs layout))])
    (define chain (cadr row))
    (define addr (caddr row))
    (when (hash-ref local chain #f)
      (problem! `(external-conflict ,chain)))
    (cond
      [(not addr)
       (set! unlinked (cons chain unlinked))
       (problem! `(unlinked-external ,chain))]
      [(odd? addr)
       (problem! `(misaligned-external ,chain ,addr))]
      [else (void)]))
  unlinked)

;; ---------------------------------------------------------------------------
;; 地址表达式 / 目标
;; ---------------------------------------------------------------------------

(define (check-chain! s chain positions unlinked problem!)
  (cond
    [(hash-ref positions chain #f) #t]
    [(member chain unlinked) #f]
    [else
     (problem! `(undefined-target
                 ,(site-seg s) ,(site-off s) ,(site-item s)))
     #f]))

(define (check-chains s expr positions unlinked problem!)
  (define ok? #t)
  (for ([c (in-list (address-expr-chains expr))])
    (unless (check-chain! s c positions unlinked problem!)
      (set! ok? #f)))
  ok?)

;; ---------------------------------------------------------------------------
;; 控制转移: 只检查前端显式选择的形式
;; ---------------------------------------------------------------------------

(define (check-control s positions unlinked xlen problem!)
  (define it (site-item s))
  (when (control-form? it)
    (define target (normalize-path (control-target it)))
    (cond
      [(not target)
       (problem! `(undefined-target ,(site-seg s) ,(site-off s) ,it))]
      [else
       (define addr (hash-ref positions target #f))
       (cond
         [(not addr)
          ;; 未链接的外部符号已经由 check-externs 报过, 不再重复 undefined-target
          (unless (member target unlinked)
            (problem! `(undefined-target ,(site-seg s) ,(site-off s) ,it)))]
         [else
          (check-control-target s it addr xlen problem!)])])))

;; 已经知道目标地址: 只检查显式形式自己的约束
(define (check-control-target s it addr xlen problem!)
  (define here (site-here s))
  (define d (- addr here))
  ;; 所有直接控制转移的目标都必须是偶数字节地址
  (when (odd? addr)
    (problem! `(misaligned-target ,(site-seg s) ,(site-off s) ,it ,addr)))
  (case (car it)
    ;; (branch-jal cond rs1 rs2 L) = 反向分支 + jal
    ;; form-range 已经把 jal 在 +4 的偏置算进去
    [(branch-jal)
     (define range (form-range it))
     (unless (<= (car range) d (cdr range))
       (problem! `(out-of-range ,(site-seg s) ,(site-off s) ,it ,d ,range)))]

    ;; (branch-auipc-jalr tmp cond rs1 rs2 L)
    ;; auipc 在 branch 之后 4 字节, 所以 delta 相对 (here + 4)
    [(branch-auipc-jalr)
     (unless (fits-auipc-pair? (- addr (+ here 4)) xlen)
       (problem! `(out-of-range ,(site-seg s) ,(site-off s) ,it ,d auipc-pair)))]

    ;; (jump-auipc-jalr link base L)
    ;; auipc 就是 item 本身, delta 相对 here
    [(jump-auipc-jalr)
     (unless (fits-auipc-pair? d xlen)
       (problem! `(out-of-range ,(site-seg s) ,(site-off s) ,it ,d auipc-pair)))]

    [else
     (define range (form-range it))
     (when (and range (not (<= (car range) d (cdr range))))
       (problem! `(out-of-range ,(site-seg s) ,(site-off s) ,it ,d ,range)))]))

;; ---------------------------------------------------------------------------
;; scratch/base/tmp: 都是必需操作数, 只检查值是否合法
;; ---------------------------------------------------------------------------

(define (check-scratch s problem!)
  (define it (site-item s))
  (define (zero! reg)
    (when (and reg (zero-register? reg))
      (problem! `(zero-scratch
                  ,(site-seg s) ,(site-off s) ,it))))
  (define (distinct! a b)
    (when (and a b (same-register? a b))
      (problem! `(bad-scratch
                  ,(site-seg s) ,(site-off s) ,it))))
  (case (car it)
    [(branch-auipc-jalr)
     (zero! (branch-auipc-jalr-scratch it))]
    [(jump-auipc-jalr)
     (zero! (jump-auipc-jalr-base it))]
    [(la-pcrel-li-add)
     (define tmp (la-pcrel-li-add-tmp it))
     (zero! tmp)
     ;; auipc rd ; li tmp ; add rd,rd,tmp: tmp 不能和 rd 重合
     (distinct! (cadr it) tmp)]
    [else (void)]))

;; ---------------------------------------------------------------------------
;; 近 la-pcrel: 够不着就报错, 让前端显式改写成 la-pcrel-li-add
;; ---------------------------------------------------------------------------

(define (check-la s positions unlinked xlen problem!)
  (define it (site-item s))
  (when (la-pcrel-form? it)
    (define expr (last it))
    (when (check-chains s expr positions unlinked problem!)
      (define addr (eval-address expr (lambda (c) (hash-ref positions c #f))))
      (define d (- addr (site-here s)))
      (unless (fits-auipc-pair? d xlen)
        (problem! `(la-too-far
                    ,(site-seg s) ,(site-off s) ,(site-item s) ,d))))))

;; ---------------------------------------------------------------------------
;; 数据里的地址值: 只检查链存在; 宽度由 bind-labels 用最终地址查
;; ---------------------------------------------------------------------------

(define (check-value s positions unlinked problem!)
  (define it (site-item s))
  (when (value-form? it)
    (define v (value-payload it))
    (when (not (exact-integer? v))
      (check-chains s v positions unlinked problem!))))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (check-layout target layout)
  (unless (eq? (layout-phase layout) 'measured)
    (error 'check
           "需要 measured-layout，先跑 layout（当前 phase: ~e）"
           (layout-phase layout)))
  (define xlen (target-xlen target))
  (define positions (collect-positions layout))
  (define problems '())
  (define (problem! p) (set! problems (cons p problems)))
  (define unlinked (check-externs layout problem!))

  (for ([seg (in-list (layout-segments layout))])
    (define seg-name (segment-field seg 'name))
    (define start (segment-field seg 'start))
    (for ([entry (in-list (segment-items seg))])
      (define off (cadr entry))
      (define it (caddr entry))
      (define s (site seg-name off it (+ start off)))
      (check-control s positions unlinked xlen problem!)
      (check-scratch s problem!)
      (check-la s positions unlinked xlen problem!)
      (check-value s positions unlinked problem!)))

  (set-layout-field layout 'problems
                    (append (layout-problems layout)
                            (reverse problems))))
