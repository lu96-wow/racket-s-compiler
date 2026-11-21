#lang racket
;;; ir/shape.rkt
;;;
;;; virtual IR 的形状。只回答“这个 s-exp 是不是某个形状”，
;;; 不检查名字是否已声明、CFG 是否可达、寄存器够不够。
;;;
;;; 这里仍然只用 list / symbol 操作；寄存器名的 x0..x31 检查是
;;; physical register 的词法契约，不是 operand 形状推断。

(require "../core/sexp.rkt")

(provide type-name?
         type-form?
         vreg-decl?
         vreg-decl-name
         vreg-decl-type
         vreg-decl-options
         vreg-decl-address-taken?
         vreg-option?
         alloc-form?
         alloc-entry?
         reserve-entry?
         pin-entry?
         clobber-entry?
         entry-form?
         block-form?
         term-form?
         term-expr-form?
         condition-form?
         condition-head?
         virtual-op-head?
         binary-op-head?
         asm-form?
         asm-clause?
         asm-binding-entry?
         asm-clobber-entry?
         asm-clause-head
         physical-register?
         forbidden-virtual-head?)

;; ---------------------------------------------------------------------------
;; 类型
;; ---------------------------------------------------------------------------

(define type-names
  '(b8 b16 b32 b64 s8 s16 s32 ptr))

(define (type-name? x)
  (and (symbol? x) (and (memq x type-names) #t)))

(define (type-form? x)
  (match x
    [(list (? type-name?)) #t]
    [_ #f]))

;; ---------------------------------------------------------------------------
;; vregs
;; ---------------------------------------------------------------------------

(define (vreg-option? x)
  (match x
    [(list 'align (? exact-positive-integer?)) #t]
    [(list 'address-taken) #t]
    [_ #f]))

;; (($ name) type option ...)
(define (vreg-decl? x)
  (and (form? x)
       (>= (length x) 2)
       (vreg? (car x))
       (type-form? (cadr x))
       (andmap vreg-option? (cddr x))))

(define (vreg-decl-name decl)
  (cadr (car decl)))

(define (vreg-decl-type decl)
  (cadr decl))

(define (vreg-decl-options decl)
  (cddr decl))

(define (vreg-decl-address-taken? decl)
  (and (vreg-decl? decl)
       (ormap (lambda (option) (equal? option '(address-taken)))
              (vreg-decl-options decl))))

;; ---------------------------------------------------------------------------
;; alloc
;; ---------------------------------------------------------------------------

(define (reserve-entry? x)
  (match x
    [(list 'reserve (? physical-register?)) #t]
    [_ #f]))

(define (pin-entry? x)
  (match x
    [(list 'pin (? vreg? _) (? physical-register?)) #t]
    [_ #f]))

(define (clobber-entry? x)
  (and (tagged? x 'clobber)
       (andmap physical-register? (cdr x))))

(define (alloc-entry? x)
  (or (reserve-entry? x)
      (pin-entry? x)
      (clobber-entry? x)))

(define (alloc-form? x)
  (and (tagged? x 'alloc)
       (andmap alloc-entry? (cdr x))))

;; ---------------------------------------------------------------------------
;; entry / block / term
;; ---------------------------------------------------------------------------

(define (entry-form? x)
  (match x
    [(list 'entry (? symbol?)) #t]
    [_ #f]))

(define (condition-head? h)
  (and (symbol? h) (and (memq h '(eq ne lt le ltu leu)) #t)))

(define (condition-form? x)
  (match x
    [(list (? condition-head?) _ _) #t]
    [_ #f]))

(define (term-expr-form? x)
  (match x
    [(list 'jump (? symbol?)) #t]
    [(list 'branch (? condition-form?) (? symbol?) (? symbol?)) #t]
    [(list 'return _ ...) #t]
    [(list 'trap) #t]
    [_ #f]))

(define (term-form? x)
  (and (tagged? x 'term)
       (= 2 (length x))
       (term-expr-form? (cadr x))))

;; (block name op ... (term ...))；term 的位置由 verify 检查。
(define (block-form? x)
  (and (tagged? x 'block)
       (>= (length x) 3)
       (symbol? (cadr x))))

;; ---------------------------------------------------------------------------
;; 普通 op
;; ---------------------------------------------------------------------------

(define binary-op-heads
  '(add sub and or xor shl shr sar mul div divu rem remu))

(define virtual-op-heads
  (append '(const copy load store addr call asm)
          binary-op-heads))

(define (binary-op-head? h)
  (and (symbol? h) (and (memq h binary-op-heads) #t)))

(define (virtual-op-head? h)
  (and (symbol? h) (and (memq h virtual-op-heads) #t)))

;; ---------------------------------------------------------------------------
;; asm
;; ---------------------------------------------------------------------------

(define (asm-form? x)
  (tagged? x 'asm))

(define (asm-clause-head x)
  (and (form? x) (car x)))

(define (asm-clause? x)
  (and (form? x)
       (memq (car x) '(inputs outputs clobber code))
       #t))

;; ((vreg) (native xN))
(define (asm-binding-entry? x)
  (match x
    [(list (? vreg? _) (? physical-register?)) #t]
    [_ #f]))

(define (asm-clobber-entry? x)
  (physical-register? x))

;; ---------------------------------------------------------------------------
;; 物理寄存器 / C ABI 名字
;; ---------------------------------------------------------------------------

;; (native xN)，N 在 0..31。
(define (native-register-name? name)
  (and (symbol? name)
       (regexp-match? #rx"^x([0-9]|[12][0-9]|3[01])$" (symbol->string name))))

(define (physical-register? x)
  (and (native? x) (native-register-name? (cadr x))))

;; 核心 IR 不接受 ABI 别名：操作数只有 ($ name) / (native xN) / (global chain)，
;; 写 a0 既不是 vreg 也不是 native，形状检查会直接拒绝。

;; virtual IR 里不应出现的 machine / control / module 形状。
;; native 不在表里：alloc 和 asm 的边界需要它，普通 op 由 op 检查拒绝。
(define forbidden-virtual-heads
  '(label j jal jalr ret
    beq bne blt bge bltu bgeu beqz bnez ble bgt
    c.j c.jal c.beqz c.bnez
    slot frame frame-slot scratch allocation
    raw data func module provide require))

(define (forbidden-virtual-head? h)
  (and (symbol? h) (and (memq h forbidden-virtual-heads) #t)))
