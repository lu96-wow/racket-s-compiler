#lang racket/base

;; ============================================================
;; representation types
;;
;; 目标不是源码类型系统，而是后端需要的“表示类型”：
;;   - 存储宽度 / 对齐
;;   - 是否是指针（GC / pb*）
;;   - 是否是带标签的 Lisp 值（#t #f 'nil / value）
;;
;; 类型语法：
;;   b8 b16 b32 b64          无符号宽度；signed/unsigned 由操作决定
;;   pb8 pb16 pb32 pb64      指向对应宽度的指针（指针本身 64 位）
;;   (ptr T)                 通用指针写法
;;   (struct S)              结构体（按值）
;;   (array T n)             数组
;;   value                   带标签的 64 位 Lisp 值
;;   bool / nil              value 的子集，方便标注
;;
;; 字面值：
;;   #t #f 'nil
;;   value 的 tag 方案固定，见文件末尾。
;; ============================================================

(require racket/list)

(provide scalar-repr?
         pointer-repr?
         value-repr?
         struct-repr?
         array-repr?
         repr?
         repr-slot?
         repr-width
         repr-align
         repr->sexpr

         repr-form?
         slot-decl-repr-form?

         struct-form?
         struct-field?
         struct-name
         struct-fields
         struct-field-name
         struct-field-repr
         struct-layout
         struct-size
         struct-align
         struct-field-offset

         value-literal?
         literal-repr
         literal-encode
         literal->sexpr

         const-form?
         const-dst
         const-value

         VALUE-TAG-MASK
         VALUE-TAG-SPECIAL
         SPECIAL-FALSE
         SPECIAL-TRUE
         SPECIAL-NIL
         SPECIAL-EOF)

;; ------------------------------------------------------------
;; 标量 / 指针 / 值
;; ------------------------------------------------------------

(define scalar-reprs '(b8 b16 b32 b64))
(define pointer-reprs '(pb8 pb16 pb32 pb64))
(define value-reprs '(value bool nil))

(define (scalar-repr? repr)
  (and (memq repr scalar-reprs) #t))

(define (pointer-repr? repr)
  (or (and (memq repr pointer-reprs) #t)
      (and (list? repr)
           (= (length repr) 2)
           (eq? (car repr) 'ptr)
           (repr? (cadr repr))
           #t)))

(define (value-repr? repr)
  (and (memq repr value-reprs) #t))

(define (struct-repr? repr)
  (and (list? repr)
       (= (length repr) 2)
       (eq? (car repr) 'struct)
       (symbol? (cadr repr))))

(define (array-repr? repr)
  (and (list? repr)
       (= (length repr) 3)
       (eq? (car repr) 'array)
       (repr? (cadr repr))
       (exact-nonnegative-integer? (caddr repr))))

(define (repr? repr)
  (or (scalar-repr? repr)
      (pointer-repr? repr)
      (value-repr? repr)
      (struct-repr? repr)
      (array-repr? repr)
      #f))

;; frame slot 是一个机器字；结构体/数组要存指针。
(define (repr-slot? repr)
  (or (scalar-repr? repr)
      (pointer-repr? repr)
      (value-repr? repr)
      #f))

(define (repr->sexpr repr) repr)

;; ------------------------------------------------------------
;; 宽度 / 对齐
;; ------------------------------------------------------------

(define (align-up n alignment)
  (* alignment (quotient (+ n (sub1 alignment)) alignment)))

(define (repr-width repr [structs '()])
  (cond
    [(eq? repr 'b8) 1]
    [(eq? repr 'b16) 2]
    [(eq? repr 'b32) 4]
    [(eq? repr 'b64) 8]
    [(memq repr pointer-reprs) 8]
    [(and (list? repr) (eq? (car repr) 'ptr)) 8]
    [(memq repr value-reprs) 8]
    [(struct-repr? repr)
     (define entry (assoc (cadr repr) structs))
     (unless entry
       (error 'repr-width "unknown struct type: ~a" (cadr repr)))
     (struct-size (cdr entry))]
    [(array-repr? repr)
     (* (caddr repr) (repr-width (cadr repr) structs))]
    [else
     (error 'repr-width "not a repr: ~a" repr)]))

(define (repr-align repr [structs '()])
  (cond
    [(eq? repr 'b8) 1]
    [(eq? repr 'b16) 2]
    [(eq? repr 'b32) 4]
    [(eq? repr 'b64) 8]
    [(memq repr pointer-reprs) 8]
    [(and (list? repr) (eq? (car repr) 'ptr)) 8]
    [(memq repr value-reprs) 8]
    [(struct-repr? repr)
     (define entry (assoc (cadr repr) structs))
     (unless entry
       (error 'repr-align "unknown struct type: ~a" (cadr repr)))
     (struct-align (cdr entry))]
    [(array-repr? repr)
     (repr-align (cadr repr) structs)]
    [else
     (error 'repr-align "not a repr: ~a" repr)]))

;; ------------------------------------------------------------
;; repr 形式与 slot 声明
;; ------------------------------------------------------------

(define (repr-form? value)
  (and (list? value)
       (= (length value) 2)
       (eq? (car value) 'repr)
       (repr? (cadr value))
       #t))

(define (slot-decl-repr-form? value)
  (and (repr-form? value)
       (repr-slot? (cadr value))
       #t))

;; ------------------------------------------------------------
;; 结构体
;; ------------------------------------------------------------

(define (struct-field? value)
  (and (list? value)
       (= (length value) 3)
       (eq? (car value) 'field)
       (symbol? (cadr value))
       (let ([repr (caddr value)])
         (and (repr? repr)
              ;; 第一版：字段必须是单字大小或指针/值。
              (not (struct-repr? repr))
              (not (array-repr? repr))))))

(define (struct-form? value)
  (and (list? value)
       (>= (length value) 2)
       (eq? (car value) 'struct)
       (symbol? (cadr value))
       (andmap struct-field? (cddr value))))

(define (struct-name value) (cadr value))
(define (struct-fields value) (cddr value))
(define (struct-field-name field) (cadr field))
(define (struct-field-repr field) (caddr field))

;; 返回 ((name offset repr) ...), size, align
(define (struct-layout value)
  (unless (struct-form? value)
    (error 'struct-layout "not a struct form: ~a" value))
  (define fields (struct-fields value))
  (define-values (layout size max-align)
    (for/fold ([layout '()]
               [offset 0]
               [max-align 1])
              ([field (in-list fields)])
      (define repr (struct-field-repr field))
      (define align (repr-align repr))
      (define width (repr-width repr))
      (define offset* (align-up offset align))
      (values (append layout
                      (list (list (struct-field-name field) offset* repr)))
              (+ offset* width)
              (max max-align align))))
  (values layout
          (align-up size max-align)
          max-align))

(define (struct-size value)
  (define-values (_layout size _align) (struct-layout value))
  size)

(define (struct-align value)
  (define-values (_layout _size align) (struct-layout value))
  align)

(define (struct-field-offset value field-name)
  (define-values (layout _size _align) (struct-layout value))
  (cond
    [(assoc field-name layout) => cadr]
    [else
     (error 'struct-field-offset
            "struct ~a has no field ~a"
            (struct-name value) field-name)]))

;; ------------------------------------------------------------
;; Lisp 字面值：固定 tag 编码
;;
;; 低 3 位：
;;   000 fixnum
;;   001 char
;;   010 cons pointer
;;   011 symbol pointer
;;   100 string pointer
;;   101 vector pointer
;;   110 closure pointer
;;   111 special
;;
;; special = (code << 3) | 7：
;;   #f = 7, #t = 15, 'nil = 23, eof = 31
;; ------------------------------------------------------------

(define VALUE-TAG-MASK 7)
(define VALUE-TAG-SPECIAL 7)

(define SPECIAL-FALSE 0)
(define SPECIAL-TRUE 1)
(define SPECIAL-NIL 2)
(define SPECIAL-EOF 3)

(define (nil-literal? value)
  (or (eq? value 'nil)
      (equal? value '(quote nil))))

(define (value-literal? value)
  (or (boolean? value)
      (nil-literal? value)
      (exact-integer? value)))

(define (literal-repr value)
  (cond
    [(boolean? value) 'bool]
    [(nil-literal? value) 'nil]
    [(exact-integer? value) 'b64]
    [else (error 'literal-repr "not a literal: ~a" value)]))

(define (literal-encode value)
  (cond
    [(eq? value #f) (bitwise-ior (arithmetic-shift SPECIAL-FALSE 3)
                                 VALUE-TAG-SPECIAL)]
    [(eq? value #t) (bitwise-ior (arithmetic-shift SPECIAL-TRUE 3)
                                 VALUE-TAG-SPECIAL)]
    [(nil-literal? value) (bitwise-ior (arithmetic-shift SPECIAL-NIL 3)
                                       VALUE-TAG-SPECIAL)]
    [(exact-integer? value) value]
    [else (error 'literal-encode "not a literal: ~a" value)]))

(define (literal->sexpr value)
  (cond
    [(boolean? value) value]
    [(nil-literal? value) '(quote nil)]
    [(exact-integer? value) value]
    [else (error 'literal->sexpr "not a literal: ~a" value)]))

;; ------------------------------------------------------------
;; const 伪指令：把字面值物化进寄存器
;; ------------------------------------------------------------

(define (const-form? value)
  (and (list? value)
       (= (length value) 3)
       (eq? (car value) 'const)
       (symbol? (cadr value))
       (value-literal? (caddr value))))

(define (const-dst value) (cadr value))
(define (const-value value) (caddr value))
