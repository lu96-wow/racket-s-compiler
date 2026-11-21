#lang racket
;;; ir/materialize.rkt
;;;
;;; virtual IR + allocation -> machine IR。
;;;
;;; 第一版 stack-first 规则：
;;;   - 寄存器位置的 vreg -> (native xN)
;;;   - slot 位置的 vreg -> load/store + scratch
;;;   - (addr dst ($ x)) -> (addr machine-dst (frame-slot n))
;;;   - call 的 slot 参数先 load 到 scratch；slot 返回值在 call 后 store
;;;   - return 的 slot 操作数先 load 到 scratch
;;;   - block / term 形状不变
;;;   - materialize 之后没有 ($ x)
;;;
;;; inline asm：
;;;   - input / output 先做 parallel move；
;;;   - code 规范化为 (asm-code ...)，由 layout/encode 处理；
;;;   - clobber 不重叠 input/output 目标。

(require racket/list
         "../core/sexp.rkt"
         "shape.rkt"
         "analysis.rkt"
         "allocation.rkt"
         "scratch.rkt"
         "../asm/code.rkt")

(provide materialize-func)

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (materialize-func func allocation #:scratch [scratch '()])
  (unless (and (tagged? func 'func) (>= (length func) 2))
    (error 'materialize "expected a func: ~e" func))
  (unless (allocation-form? allocation)
    (error 'materialize "malformed allocation: ~e" allocation))

  (define scratch-regs (normalize-scratch scratch 'materialize))
  (define name (cadr func))
  (define body (cddr func))
  (define vregs (func-vreg-table func))
  (define alloc (allocation-table allocation))

  (define entry-form
    (findf (lambda (x) (and (form? x) (eq? (car x) 'entry))) body))
  (unless entry-form
    (error 'materialize "func ~a: missing entry" (chain->string name)))

  (define block-forms
    (filter (lambda (x) (and (form? x) (eq? (car x) 'block))) body))
  (define machine-blocks
    (for/list ([block (in-list block-forms)])
      (materialize-block block vregs alloc scratch-regs)))

  (define scratch-form
    (if (null? scratch-regs)
        '()
        (list (cons 'scratch scratch-regs))))

  (cons 'func
        (cons name
              (append scratch-form
                      (list entry-form)
                      machine-blocks))))

;; ---------------------------------------------------------------------------
;; block / term
;; ---------------------------------------------------------------------------

(define (materialize-block block vregs alloc scratch-regs)
  (define name (cadr block))
  (define forms (cddr block))
  (define term (last forms))
  (define ops (drop-right forms 1))

  (define machine-ops
    (append* (for/list ([op (in-list ops)])
               (materialize-op op vregs alloc scratch-regs))))
  (define-values (term-ops machine-term)
    (materialize-term term vregs alloc scratch-regs))

  (cons 'block
        (cons name
              (append machine-ops term-ops (list machine-term)))))

(define (materialize-term term vregs alloc scratch-regs)
  (define expr (cadr term))
  (match expr
    [(list 'jump (? symbol? target))
     (values '() (list 'term (list 'jump target)))]

    [(list 'trap)
     (values '() (list 'term (list 'trap)))]

    [(list 'branch (list head a b) (? symbol? then) (? symbol? else))
     (define pool (make-scratch-pool scratch-regs))
     (define-values (ma aops a-scratch) (materialize-operand a vregs alloc pool))
     (define-values (mb bops b-scratch) (materialize-operand b vregs alloc pool))
     (values (append aops bops)
             (list 'term
                   (list 'branch (list head ma mb) then else)))]

    [(list 'return operands ...)
     (define pool (make-scratch-pool scratch-regs))
     (define-values (machine-operands ops _)
       (materialize-operands operands vregs alloc pool))
     (values ops (list 'term (cons 'return machine-operands)))]

    [_ (error 'materialize "malformed term: ~e" term)]))

;; ---------------------------------------------------------------------------
;; ops
;; ---------------------------------------------------------------------------

(define (materialize-op op vregs alloc scratch-regs)
  (define pool (make-scratch-pool scratch-regs))
  (define head (car op))
  (case head
    [(const) (materialize-const op vregs alloc pool)]
    [(copy) (materialize-copy op vregs alloc pool)]
    [(load) (materialize-load op vregs alloc pool)]
    [(store) (materialize-store op vregs alloc pool)]
    [(addr) (materialize-addr op vregs alloc pool)]
    [(call) (materialize-call op vregs alloc pool)]
    [(asm) (materialize-asm op vregs alloc pool)]
    [else
     (if (binary-op-head? head)
         (materialize-binary op vregs alloc pool)
         (error 'materialize "unknown op: ~e" op))]))

(define (materialize-const op vregs alloc pool)
  (define dst (cadr op))
  (define immediate (caddr op))
  (define-values (mdst post) (materialize-dst dst vregs alloc pool))
  (append (list (list 'const mdst immediate)) post))

(define (materialize-binary op vregs alloc pool)
  (define head (car op))
  (define dst (cadr op))
  (define a (caddr op))
  (define b (cadddr op))
  (define-values (ma aops asrc) (materialize-operand a vregs alloc pool))
  (define-values (mb bops bsrc) (materialize-operand b vregs alloc pool))
  (define-values (mdst post)
    (materialize-dst dst vregs alloc pool (or asrc bsrc)))
  (append aops bops
          (list (list head mdst ma mb))
          post))

(define (materialize-copy op vregs alloc pool)
  (define dst (cadr op))
  (define src (caddr op))
  (define dst-loc (vreg-location dst alloc))
  (define src-loc (and (vreg? src) (vreg-location src alloc)))

  (cond
    ;; 直接 load：dst 寄存器，src 是 slot
    [(and (physical-register? dst-loc)
          src-loc
          (slot-location? src-loc))
     (list (list 'load dst-loc
                 (frame-slot src-loc) 0
                 (vreg-type vregs src)))]

    ;; 直接 store：dst 是 slot，src 是寄存器
    [(and (slot-location? dst-loc)
          src-loc
          (physical-register? src-loc))
     (list (list 'store (frame-slot dst-loc) 0 src-loc
                 (vreg-type vregs dst)))]

    ;; slot -> slot
    [(and (slot-location? dst-loc)
          src-loc
          (slot-location? src-loc))
     (define reg (take-scratch! pool))
     (list (list 'load reg (frame-slot src-loc) 0 (vreg-type vregs src))
           (list 'store (frame-slot dst-loc) 0 reg (vreg-type vregs dst)))]

    ;; dst 是 slot，src 是 integer/global
    [(slot-location? dst-loc)
     (define reg (take-scratch! pool))
     (list (list 'copy reg src)
           (list 'store (frame-slot dst-loc) 0 reg (vreg-type vregs dst)))]

    ;; dst 是寄存器
    [(physical-register? dst-loc)
     (cond
       [src-loc
        (list (list 'copy dst-loc src-loc))]
       [else
        (list (list 'copy dst-loc src))])]

    [else
     (error 'materialize "invalid copy destination location: ~e" dst-loc)]))

(define (materialize-load op vregs alloc pool)
  (define dst (cadr op))
  (define base (caddr op))
  (define offset (cadddr op))
  (define type (car (cddddr op)))

  (define-values (mbase bops _)
    (materialize-operand base vregs alloc pool))
  (define dst-loc (vreg-location dst alloc))

  (cond
    [(physical-register? dst-loc)
     (append bops
             (list (list 'load dst-loc mbase offset type)))]

    [(slot-location? dst-loc)
     (define reg (take-scratch! pool))
     (append bops
             (list (list 'load reg mbase offset type)
                   (list 'store (frame-slot dst-loc) 0 reg
                         (vreg-type vregs dst))))]

    [else
     (error 'materialize "invalid load destination location: ~e" dst-loc)]))

(define (materialize-store op vregs alloc pool)
  (define base (cadr op))
  (define offset (caddr op))
  (define src (cadddr op))
  (define type (car (cddddr op)))

  (define-values (mbase bops base-scratch)
    (materialize-operand base vregs alloc pool))
  (define-values (msrc sops src-scratch)
    (materialize-operand src vregs alloc pool))
  (append bops sops
          (list (list 'store mbase offset msrc type))))

(define (materialize-addr op vregs alloc pool)
  (define dst (cadr op))
  (define src (caddr op))
  (define machine-src
    (cond
      [(global-ref? src) src]
      [(vreg? src)
       (define loc (vreg-location src alloc))
       (unless (slot-location? loc)
         (error 'materialize "addr source ~a must be in a slot, got: ~e"
                (vreg->string src) loc))
       (frame-slot loc)]
      [else
       (error 'materialize "invalid addr source: ~e" src)]))

  (define dst-loc (vreg-location dst alloc))
  (cond
    [(physical-register? dst-loc)
     (list (list 'addr dst-loc machine-src))]
    [(slot-location? dst-loc)
     (define reg (take-scratch! pool))
     (list (list 'addr reg machine-src)
           (list 'store (frame-slot dst-loc) 0 reg
                 (vreg-type vregs dst)))]
    [else
     (error 'materialize "invalid addr destination location: ~e" dst-loc)]))

(define (materialize-call op vregs alloc pool)
  (define dst (cadr op))
  (define target (caddr op))
  (define args (cdddr op))

  (define-values (margs arg-ops arg-scratches)
    (materialize-operands args vregs alloc pool))

  (define dst-loc (vreg-location dst alloc))
  (cond
    [(physical-register? dst-loc)
     (append arg-ops
             (list (list* 'call dst-loc target margs)))]

    [(slot-location? dst-loc)
     ;; 参数已经写到 outgoing area 后，参数用的 scratch 就自由了；
     ;; 能复用就复用，避免为返回值再要一个 scratch。
     (define dst-reg
       (or (and (pair? arg-scratches) (car arg-scratches))
           (take-scratch! pool)))
     (append arg-ops
             (list (list* 'call dst-reg target margs)
                   (list 'store (frame-slot dst-loc) 0 dst-reg
                         (vreg-type vregs dst))))]

    [else
     (error 'materialize "invalid call destination location: ~e" dst-loc)]))

;; ---------------------------------------------------------------------------
;; inline asm
;; ---------------------------------------------------------------------------

(struct pmove (dst src emit) #:transparent)

(define (asm-clause op key)
  (assoc key (cdr op)))

(define (asm-binding-pairs clause)
  (for/list ([entry (in-list (cdr clause))])
    (list (car entry) (cadr entry))))

(define (materialize-asm op vregs alloc pool)
  (define inputs-clause (asm-clause op 'inputs))
  (define outputs-clause (asm-clause op 'outputs))
  (define clobbers-clause (asm-clause op 'clobber))
  (define code-clause (asm-clause op 'code))
  (unless (and inputs-clause outputs-clause clobbers-clause code-clause)
    (error 'materialize "asm is missing inputs/outputs/clobber/code: ~e" op))

  (define input-pairs (asm-binding-pairs inputs-clause))
  (define output-pairs (asm-binding-pairs outputs-clause))
  (define clobbers (cdr clobbers-clause))
  (define code (cdr code-clause))
  (check-asm-bindings input-pairs output-pairs clobbers)

  (define code-layout (normalize-asm-code code))

  (define input-moves
    (for/list ([pair (in-list (remove-duplicate-bindings input-pairs))])
      (define vreg (car pair))
      (define target (cadr pair))
      (define loc (vreg-location vreg alloc))
      (cond
        [(physical-register? loc)
         (and (not (equal? loc target))
              (pmove target loc (lambda (src) (list 'copy target src))))]
        [(slot-location? loc)
         (pmove target #f
                (lambda (_src)
                  (list 'load target (frame-slot loc) 0 (vreg-type vregs vreg))))]
        [else
         (error 'materialize "invalid asm input location for ~a: ~e"
                (vreg->string vreg) loc)])))

  (define output-moves
    (for/list ([pair (in-list (remove-duplicate-bindings output-pairs))])
      (define vreg (car pair))
      (define target (cadr pair))
      (define loc (vreg-location vreg alloc))
      (cond
        [(physical-register? loc)
         (and (not (equal? loc target))
              (pmove loc target (lambda (src) (list 'copy loc src))))]
        [(slot-location? loc)
         (pmove #f target
                (lambda (src)
                  (list 'store (frame-slot loc) 0 src (vreg-type vregs vreg))))]
        [else
         (error 'materialize "invalid asm output location for ~a: ~e"
                (vreg->string vreg) loc)])))

  (append (parallel-move-ops (filter values input-moves) pool)
          (list (cons 'asm-code (asm-code-layout-items code-layout)))
          (parallel-move-ops (filter values output-moves) pool)))

(define (remove-duplicate-bindings pairs)
  (define seen (make-hash))
  (for/fold ([out '()]) ([pair (in-list pairs)])
    (if (hash-has-key? seen pair)
        out
        (begin
          (hash-set! seen pair #t)
          (append out (list pair))))))

(define (check-asm-bindings inputs outputs clobbers)
  (define vreg->reg (make-hash))
  (define input-reg->vreg (make-hash))
  (define output-reg->vreg (make-hash))

  (for ([pair (in-list (append inputs outputs))])
    (define vreg (car pair))
    (define reg (cadr pair))
    (define previous (hash-ref vreg->reg vreg #f))
    (when (and previous (not (equal? previous reg)))
      (error 'materialize "asm binds ~a to two registers (~e and ~e)"
             (vreg->string vreg) previous reg))
    (hash-set! vreg->reg vreg reg))

  (for ([pair (in-list inputs)])
    (define vreg (car pair))
    (define reg (cadr pair))
    (define previous (hash-ref input-reg->vreg reg #f))
    (when (and previous (not (equal? previous vreg)))
      (error 'materialize
             "asm input register ~e is bound to two vregs (~a and ~a)"
             reg (vreg->string previous) (vreg->string vreg)))
    (hash-set! input-reg->vreg reg vreg))

  (for ([pair (in-list outputs)])
    (define vreg (car pair))
    (define reg (cadr pair))
    (define previous (hash-ref output-reg->vreg reg #f))
    (when (and previous (not (equal? previous vreg)))
      (error 'materialize
             "asm output register ~e is bound to two vregs (~a and ~a)"
             reg (vreg->string previous) (vreg->string vreg)))
    (hash-set! output-reg->vreg reg vreg))

  (for ([reg (in-list clobbers)])
    (when (or (hash-has-key? input-reg->vreg reg)
              (hash-has-key? output-reg->vreg reg))
      (error 'materialize "asm clobber ~e overlaps an input/output register"
             reg))))

;; 处理 parallel copy：dst 可能物理寄存器或 #f（写内存）；src 可能物理寄存器或 #f。
(define (parallel-move-ops moves pool)
  (let loop ([remaining moves] [out '()])
    (cond
      [(null? remaining) (reverse out)]
      [else
       (define srcs
         (for/hash ([m (in-list remaining)]
                    #:when (physical-register? (pmove-src m)))
           (values (pmove-src m) #t)))
       (define ready
         (findf (lambda (m)
                  (not (and (physical-register? (pmove-dst m))
                            (hash-has-key? srcs (pmove-dst m)))))
                remaining))
       (cond
         [ready
          (define op ((pmove-emit ready) (pmove-src ready)))
          (loop (filter (lambda (m) (not (eq? m ready))) remaining)
                (cons op out))]
         [else
          ;; 所有剩余 move 的 dst 都是某个 move 的 src：存在环，用 scratch 打断。
          (define m (findf (lambda (m) (physical-register? (pmove-src m))) remaining))
          (unless m
            (error 'materialize "internal: stuck asm parallel move"))
          (define scratch (take-scratch! pool 'materialize))
          (when (or (hash-has-key? srcs scratch)
                    (for/or ([x (in-list remaining)])
                      (and (physical-register? (pmove-dst x))
                           (equal? (pmove-dst x) scratch))))
            (error 'materialize
                   "asm move needs a scratch register not used as a move source/destination"))
          (define save (list 'copy scratch (pmove-src m)))
          (define m* (pmove (pmove-dst m) scratch (pmove-emit m)))
          (loop (cons m* (filter (lambda (x) (not (eq? x m))) remaining))
                (cons save out))])])))

;; ---------------------------------------------------------------------------
;; 操作数
;; ---------------------------------------------------------------------------

;; 按顺序 materialize 一组 operand。
;; 返回 (values machine-operands prelude-ops scratch-registers-used)。
(define (materialize-operands operands vregs alloc pool)
  (for/fold ([ms '()] [ops '()] [scratches '()])
            ([operand (in-list operands)])
    (define-values (m pre scratch)
      (materialize-operand operand vregs alloc pool))
    (values (append ms (list m))
            (append ops pre)
            (if scratch (cons scratch scratches) scratches))))

;; 返回 (values machine-operand prelude-ops scratch-used-or-#f)
(define (materialize-operand operand vregs alloc pool)
  (cond
    [(exact-integer? operand)
     (values operand '() #f)]

    [(global-ref? operand)
     (values operand '() #f)]

    [(vreg? operand)
     (define loc (vreg-location operand alloc))
     (cond
       [(physical-register? loc)
        (values loc '() #f)]
       [(slot-location? loc)
        (define reg (take-scratch! pool))
        (define type (vreg-type vregs operand))
        (values reg
                (list (list 'load reg (frame-slot loc) 0 type))
                reg)]
       [else
        (error 'materialize "invalid location for ~a: ~e"
               (vreg->string operand) loc)])]

    [else
     (error 'materialize "invalid operand: ~e" operand)]))

;; 返回 (values machine-dst post-ops)
(define (materialize-dst dst vregs alloc pool [reuse #f])
  (define loc (vreg-location dst alloc))
  (cond
    [(physical-register? loc)
     (values loc '())]
    [(slot-location? loc)
     (define reg (or reuse (take-scratch! pool)))
     (define type (vreg-type vregs dst))
     (values reg
             (list (list 'store (frame-slot loc) 0 reg type)))]
    [else
     (error 'materialize "invalid destination location for ~a: ~e"
            (vreg->string dst) loc)]))

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (vreg-location vreg alloc)
  (or (hash-ref alloc vreg #f)
      (error 'materialize "vreg ~a has no allocation entry"
             (vreg->string vreg))))

(define (vreg-type vregs vreg)
  (define decl (hash-ref vregs vreg #f))
  (unless decl
    (error 'materialize "vreg ~a is not declared" (vreg->string vreg)))
  (vreg-decl-type decl))

(define (frame-slot location)
  (list 'frame-slot (cadr location)))

(define (vreg->string vreg)
  (format "($ ~a)" (cadr vreg)))
