#lang racket
;;; ir/lower.rkt
;;;
;;; lower-ops：machine IR -> selected machine IR。
;;;
;;; 只做指令选择，不新增 vreg，不改 CFG，不选 b/j 形式。
;;;
;;; 处理：
;;;   const / copy / 二元算术 / load / store / addr(frame-slot)
;;;
;;; 留给后面：
;;;   call / return / asm / addr(global) / 条件分支形式。
;;;
;;; 生成的都是 native 形式，寄存器继续写 (native xN)。
;;; 存储指令用 native 顺序：
;;;   load  : (lw  rd rs1 imm)
;;;   store : (sw  imm rs1 rs2)

(require racket/list
         "../../riscv-help/ranges.rkt"
         "../core/sexp.rkt"
         "shape.rkt"
         "frame.rkt"
         "li.rkt"
         "scratch.rkt")

(provide lower-func)

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (lower-func func frame
                   #:xlen [xlen 64]
                   #:fp [fp '(native x8)]
                   #:scratch [scratch #f])
  (unless (and (tagged? func 'func) (>= (length func) 2))
    (error 'lower "expected a func: ~e" func))
  (unless (frame-form? frame)
    (error 'lower "malformed frame: ~e" frame))
  (unless (memq xlen '(32 64))
    (error 'lower "xlen must be 32 or 64: ~e" xlen))
  (unless (physical-register? fp)
    (error 'lower "fp must be (native xN): ~e" fp))

  (define scratch-regs
    (if scratch
        (normalize-scratch scratch 'lower)
        (func-scratch func 'lower)))

  (define name (cadr func))
  (define body (cddr func))
  (define entry-form
    (findf (lambda (x) (and (form? x) (eq? (car x) 'entry))) body))
  (unless entry-form
    (error 'lower "func ~a: missing entry" (chain->string name)))

  (define block-forms
    (filter (lambda (x) (and (form? x) (eq? (car x) 'block))) body))
  (define lowered-blocks
    (for/list ([block (in-list block-forms)])
      (lower-block block frame xlen fp scratch-regs)))

  (define scratch-form
    (if (null? scratch-regs)
        '()
        (list (cons 'scratch scratch-regs))))

  (cons 'func
        (cons name
              (append (list frame)
                      scratch-form
                      (list entry-form)
                      lowered-blocks))))

;; ---------------------------------------------------------------------------
;; block
;; ---------------------------------------------------------------------------

(define (lower-block block frame xlen fp scratch-regs)
  (define name (cadr block))
  (define forms (cddr block))
  (define term (last forms))
  (define ops (drop-right forms 1))
  (define lowered
    (append* (for/list ([op (in-list ops)])
               (lower-op op frame xlen fp scratch-regs))))
  (cons 'block (cons name (append lowered (list term)))))

;; ---------------------------------------------------------------------------
;; ops
;; ---------------------------------------------------------------------------

(define (lower-op op frame xlen fp scratch-regs)
  (define pool (make-scratch-pool scratch-regs))
  (define head (car op))
  (case head
    [(const) (lower-const op xlen)]
    [(copy) (lower-copy op xlen)]
    [(load) (lower-load op frame xlen fp pool)]
    [(store) (lower-store op frame xlen fp pool)]
    [(addr) (lower-addr op frame xlen fp)]
    [(call) (list op)]                  ; 等 call lowering
    [(asm) (error 'lower "unlowered asm remains: ~e" op)]
    [(asm-code) (list op)]
    [else
     (if (binary-op-head? head)
         (lower-binary op xlen pool)
         (error 'lower "unknown op: ~e" op))]))

(define (lower-const op xlen)
  (define dst (cadr op))
  (define imm (caddr op))
  (unless (physical-register? dst)
    (error 'lower "const destination must be a physical register: ~e" dst))
  (emit-li dst imm xlen))

(define (lower-copy op xlen)
  (define dst (cadr op))
  (define src (caddr op))
  (unless (physical-register? dst)
    (error 'lower "copy destination must be a physical register: ~e" dst))
  (cond
    [(exact-integer? src)
     (emit-li dst src xlen)]
    [(physical-register? src)
     (list (list 'addi dst src 0))]
    [else
     (error 'lower "copy source needs address lowering: ~e" src)]))

(define (lower-binary op xlen pool)
  (define head (car op))
  (define dst (cadr op))
  (define a (caddr op))
  (define b (cadddr op))
  (unless (physical-register? dst)
    (error 'lower "binary destination must be a physical register: ~e" dst))

  (define-values (prelude instruction)
    (case head
      [(add)
       (cond
         [(and (physical-register? a) (exact-integer? b) (fits-s12? b))
          (values '() (list 'addi dst a b))]
         [(and (physical-register? b) (exact-integer? a) (fits-s12? a))
          (values '() (list 'addi dst b a))]
         [else (binary-reg 'add dst a b xlen pool)])]

      [(sub)
       (cond
         [(and (physical-register? a) (exact-integer? b) (fits-s12? (- b)))
          (values '() (list 'addi dst a (- b)))]
         [else (binary-reg 'sub dst a b xlen pool)])]

      [(and)
       (cond
         [(and (physical-register? a) (exact-integer? b) (fits-s12? b))
          (values '() (list 'andi dst a b))]
         [(and (physical-register? b) (exact-integer? a) (fits-s12? a))
          (values '() (list 'andi dst b a))]
         [else (binary-reg 'and dst a b xlen pool)])]

      [(or)
       (cond
         [(and (physical-register? a) (exact-integer? b) (fits-s12? b))
          (values '() (list 'ori dst a b))]
         [(and (physical-register? b) (exact-integer? a) (fits-s12? a))
          (values '() (list 'ori dst b a))]
         [else (binary-reg 'or dst a b xlen pool)])]

      [(xor)
       (cond
         [(and (physical-register? a) (exact-integer? b) (fits-s12? b))
          (values '() (list 'xori dst a b))]
         [(and (physical-register? b) (exact-integer? a) (fits-s12? a))
          (values '() (list 'xori dst b a))]
         [else (binary-reg 'xor dst a b xlen pool)])]

      [(shl)
       (cond
         [(and (physical-register? a) (exact-integer? b) (fits-shift-imm? b xlen))
          (values '() (list 'slli dst a b))]
         [else (binary-reg 'sll dst a b xlen pool)])]

      [(shr)
       (cond
         [(and (physical-register? a) (exact-integer? b) (fits-shift-imm? b xlen))
          (values '() (list 'srli dst a b))]
         [else (binary-reg 'srl dst a b xlen pool)])]

      [(sar)
       (cond
         [(and (physical-register? a) (exact-integer? b) (fits-shift-imm? b xlen))
          (values '() (list 'srai dst a b))]
         [else (binary-reg 'sra dst a b xlen pool)])]

      [(mul) (binary-reg 'mul dst a b xlen pool)]
      [(div) (binary-reg 'div dst a b xlen pool)]
      [(divu) (binary-reg 'divu dst a b xlen pool)]
      [(rem) (binary-reg 'rem dst a b xlen pool)]
      [(remu) (binary-reg 'remu dst a b xlen pool)]
      [else (error 'lower "unhandled binary op: ~e" head)]))
  (append prelude (list instruction)))

(define (binary-reg mnemonic dst a b xlen pool)
  (define-values (ra aops) (operand->reg a xlen pool))
  (define-values (rb bops) (operand->reg b xlen pool))
  (values (append aops bops)
          (list mnemonic dst ra rb)))

;; ---------------------------------------------------------------------------
;; load / store
;; ---------------------------------------------------------------------------

(define (lower-load op frame xlen fp pool)
  (define dst (cadr op))
  (define base (caddr op))
  (define offset (cadddr op))
  (define type (car (cddddr op)))
  (unless (physical-register? dst)
    (error 'lower "load destination must be a physical register: ~e" dst))
  (define mnemonic (load-mnemonic type xlen))
  (define-values (base-reg base-offset)
    (base->reg+offset base frame fp))
  (define mem-offset (+ base-offset offset))

  (cond
    [(fits-s12? mem-offset)
     (list (list mnemonic dst base-reg mem-offset))]
    [else
     (define scratch (take-scratch! pool))
     (append (emit-li scratch mem-offset xlen)
             (list (list 'add scratch base-reg scratch)
                   (list mnemonic dst scratch 0)))]))

(define (lower-store op frame xlen fp pool)
  (define base (cadr op))
  (define offset (caddr op))
  (define src (cadddr op))
  (define type (car (cddddr op)))
  (define mnemonic (store-mnemonic type xlen))
  (define-values (base-reg base-offset)
    (base->reg+offset base frame fp))
  (define mem-offset (+ base-offset offset))

  (define-values (src-reg src-ops)
    (cond
      [(physical-register? src) (values src '())]
      [(exact-integer? src)
       (define scratch (take-scratch! pool))
       (values scratch (emit-li scratch src xlen))]
      [else
       (error 'lower "store source needs address lowering: ~e" src)]))

  (cond
    [(fits-s12? mem-offset)
     (append src-ops
             (list (list mnemonic mem-offset base-reg src-reg)))]
    [else
     (define addr-scratch (take-scratch! pool))
     (append src-ops
             (emit-li addr-scratch mem-offset xlen)
             (list (list 'add addr-scratch base-reg addr-scratch)
                   (list mnemonic 0 addr-scratch src-reg)))]))

(define (base->reg+offset base frame fp)
  (cond
    [(physical-register? base) (values base 0)]
    [(and (form? base) (eq? (car base) 'frame-slot))
     (define slot (cadr base))
     (define slot-offset (frame-slot-offset frame slot))
     (unless slot-offset
       (error 'lower "frame-slot ~a has no frame offset" slot))
     (values fp (- slot-offset))]
    [else
     (error 'lower "base needs address lowering: ~e" base)]))

(define (load-mnemonic type xlen)
  (match type
    [(list 'b8) 'lbu]
    [(list 's8) 'lb]
    [(list 'b16) 'lhu]
    [(list 's16) 'lh]
    [(list 'b32) (if (= xlen 64) 'lwu 'lw)]
    [(list 's32) 'lw]
    [(list 'b64) (if (= xlen 64) 'ld (error 'lower "b64 load on RV32 is not implemented"))]
    [(list 'ptr) (if (= xlen 64) 'ld 'lw)]
    [_ (error 'lower "unsupported load type: ~e" type)]))

(define (store-mnemonic type xlen)
  (match type
    [(list 'b8) 'sb]
    [(list 's8) 'sb]
    [(list 'b16) 'sh]
    [(list 's16) 'sh]
    [(list 'b32) 'sw]
    [(list 's32) 'sw]
    [(list 'b64) (if (= xlen 64) 'sd (error 'lower "b64 store on RV32 is not implemented"))]
    [(list 'ptr) (if (= xlen 64) 'sd 'sw)]
    [_ (error 'lower "unsupported store type: ~e" type)]))

;; ---------------------------------------------------------------------------
;; addr
;; ---------------------------------------------------------------------------

(define (lower-addr op frame xlen fp)
  (define dst (cadr op))
  (define src (caddr op))
  (unless (physical-register? dst)
    (error 'lower "addr destination must be a physical register: ~e" dst))
  (cond
    [(and (form? src) (eq? (car src) 'frame-slot))
     (define slot (cadr src))
     (define slot-offset (frame-slot-offset frame slot))
     (unless slot-offset
       (error 'lower "frame-slot ~a has no frame offset" slot))
     (define imm (- slot-offset))
     (cond
       [(fits-s12? imm)
        (list (list 'addi dst fp imm))]
       [else
        (append (emit-li dst imm xlen)
                (list (list 'add dst fp dst)))])]
    [(global-ref? src)
     ;; 全局地址需要地址模型 / layout；先原样保留。
     (list (list 'addr dst src))]
    [else
     (error 'lower "unsupported addr source: ~e" src)]))

;; ---------------------------------------------------------------------------
;; 操作数 / scratch
;; ---------------------------------------------------------------------------

(define (operand->reg operand xlen pool)
  (cond
    [(physical-register? operand)
     (values operand '())]
    [(exact-integer? operand)
     (define scratch (take-scratch! pool))
     (values scratch (emit-li scratch operand xlen))]
    [else
     (error 'lower "operand needs address lowering: ~e" operand)]))

(define (fits-shift-imm? n xlen)
  (and (exact-nonnegative-integer? n)
       (< n xlen)))
