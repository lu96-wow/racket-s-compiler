#lang racket/base

;; ============================================================
;; repr / struct / literal 测试
;; ============================================================

(require rackunit
         racket/list
         "../repr.rkt"
         "../frame.rkt"
         "../lower-frame.rkt"
         "../literal-lower.rkt"
         "../compile-asm.rkt")

;; ------------------------------------------------------------
;; repr 语法
;; ------------------------------------------------------------

(for ([repr (in-list '(b8 b16 b32 b64
                       pb8 pb16 pb32 pb64
                       value bool nil
                       (ptr b64)
                       (ptr (struct point))
                       (struct point)
                       (array b8 16)))])
  (check-true (repr? repr) (format "repr? ~a" repr)))

(check-false (repr? 'b7))
(check-false (repr? 'u64))
(check-false (repr? '(ptr)))

(check-true (scalar-repr? 'b32))
(check-true (pointer-repr? 'pb64))
(check-true (pointer-repr? '(ptr b8)))
(check-true (value-repr? 'bool))
(check-true (struct-repr? '(struct point)))
(check-true (array-repr? '(array b16 8)))

(check-true (repr-slot? 'b64))
(check-true (repr-slot? 'pb8))
(check-true (repr-slot? 'value))
(check-false (repr-slot? '(struct point)))
(check-false (repr-slot? '(array b8 4)))

;; ------------------------------------------------------------
;; 宽度 / 对齐
;; ------------------------------------------------------------

(check-equal? (repr-width 'b8) 1)
(check-equal? (repr-width 'b16) 2)
(check-equal? (repr-width 'b32) 4)
(check-equal? (repr-width 'b64) 8)
(check-equal? (repr-width 'pb8) 8)
(check-equal? (repr-width '(ptr b8)) 8)
(check-equal? (repr-width 'value) 8)
(check-equal? (repr-width 'bool) 8)
(check-equal? (repr-width 'nil) 8)
(check-equal? (repr-width '(array b16 8)) 16)

(check-equal? (repr-align 'b8) 1)
(check-equal? (repr-align 'b16) 2)
(check-equal? (repr-align 'b32) 4)
(check-equal? (repr-align 'b64) 8)
(check-equal? (repr-align 'pb8) 8)

;; ------------------------------------------------------------
;; struct layout
;; ------------------------------------------------------------

(define point
  '(struct point
     (field x b8)
     (field y b64)))

(check-true (struct-form? point))
(check-equal? (struct-name point) 'point)
(check-equal? (struct-size point) 16)
(check-equal? (struct-align point) 8)
(check-equal? (struct-field-offset point 'x) 0)
(check-equal? (struct-field-offset point 'y) 8)

(define packed
  '(struct packed
     (field a b8)
     (field b b8)))

(check-equal? (struct-size packed) 2)
(check-equal? (struct-align packed) 1)
(check-equal? (struct-field-offset packed 'a) 0)
(check-equal? (struct-field-offset packed 'b) 1)

(define mixed
  '(struct mixed
     (field a b16)
     (field b b32)
     (field c b8)))

(check-equal? (struct-field-offset mixed 'a) 0)
(check-equal? (struct-field-offset mixed 'b) 4)
(check-equal? (struct-field-offset mixed 'c) 8)
(check-equal? (struct-size mixed) 12)
(check-equal? (struct-align mixed) 4)

;; 第一版不允许字段按值嵌套 struct。
(check-false (struct-form?
              '(struct bad (field p (struct point)))))

;; ------------------------------------------------------------
;; 字面值编码
;; ------------------------------------------------------------

(check-true (value-literal? #t))
(check-true (value-literal? #f))
(check-true (value-literal? 'nil))
(check-true (value-literal? 42))
(check-false (value-literal? 'foo))

(check-equal? (literal-repr #t) 'bool)
(check-equal? (literal-repr #f) 'bool)
(check-equal? (literal-repr 'nil) 'nil)
(check-equal? (literal-repr 42) 'b64)

(check-equal? (literal-encode #f) 7)
(check-equal? (literal-encode #t) 15)
(check-equal? (literal-encode 'nil) 23)

;; 三者必须互不相同。
(check-equal? (length (remove-duplicates
                       (list (literal-encode #f)
                             (literal-encode #t)
                             (literal-encode 'nil))))
              3)

;; ------------------------------------------------------------
;; const 形式与 lowering
;; ------------------------------------------------------------

(check-true (const-form? '(const v0 #t)))
(check-true (const-form? '(const v0 #f)))
(check-true (const-form? '(const v0 'nil)))
(check-true (const-form? '(const v0 42)))
(check-false (const-form? '(const v0 foo)))

(check-equal? (lower-literals '((label main) (const v0 #t) (return (v0))))
              '((label main) (addi v0 x0 15) (return (v0))))

(check-equal? (lower-literals '((const v0 'nil)))
              '((addi v0 x0 23)))

(check-exn
 exn:fail?
 (lambda ()
   (lower-literals '((const v0 5000)))))

;; ------------------------------------------------------------
;; slot repr
;; ------------------------------------------------------------

(check-equal? (slot-decl-repr '(slot0 (kind arg))) 'b64)
(check-equal? (slot-decl-repr '(slot0 (kind arg) (repr pb64))) 'pb64)
(check-true (slot-decl? '(slot0 (kind arg) (repr value))))
(check-false (slot-decl? '(slot0 (kind arg) (repr b7))))

(check-true
 (frame-form?
  '(frame (base fp) (link fp)
          (slots (slot0 (kind arg) (repr b64))
                 (slot1 (kind local) (repr (ptr (struct point))))
                 (slot2 (kind spill) (repr value))))))

;; frame slot 只能是一个机器字：struct/array 必须用指针。
(check-exn
 exn:fail?
 (lambda ()
   (lower-frame-forms
    '((label main)
      (frame (base fp) (link fp)
             (slots (slot0 (kind local) (repr (struct point)))))
      (return ())))))

;; ------------------------------------------------------------
;; 顶层 struct 声明会被 lower-frame-forms 抽走
;; ------------------------------------------------------------

(let ()
  (define-values (lowered frame conts structs)
    (lower-frame-forms
     '((struct point (field x b8) (field y b64))
       (label main)
       (frame (base fp) (link fp) (slots))
       (return ()))))
  (check-equal? structs
                '((struct point (field x b8) (field y b64))))
  (check-equal? frame '(frame (base fp) (link fp) (slots)))
  (check-equal? conts '())
  (check-equal? (car lowered) '(label main)))
