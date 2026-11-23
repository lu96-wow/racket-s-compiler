#lang racket/base

;;; struct-meta.rkt
;;;
;;; struct 元数据的唯一实现。
;;;
;;; 两种方向：
;;;   parse-sdef      : (struct-def ...) 元数据 -> 内部 sdef
;;;   sdef->sexp      : 内部 sdef -> (struct-def ...) 元数据
;;;   sdef->decl      : 内部 sdef -> 布局无关的 (struct name ...) 声明
;;;
;;; struct/struct.rkt 和 unit.rkt 都从这里取，避免字段/offset/padding 解析各写一份。

(require racket/list
         "sexp.rkt"
         "meta.rkt")

(provide (struct-out field)
         (struct-out align-item)
         (struct-out pad-item)
         (struct-out sdef)
         scalar-type?
         type->sexp
         field->sexp
         padding->sexp
         sdef->sexp
         sdef->decl
         struct-def-form?
         extern-struct-defs
         parse-sdef
         ordered-layout-items
         layout-item-offset)

;; ---------------------------------------------------------------------------
;; 内部表示
;; ---------------------------------------------------------------------------

(struct field (name type offset size align) #:transparent)
(struct align-item (n offset size) #:transparent)
(struct pad-item (n offset size) #:transparent)
(struct sdef (name fields items padding size align) #:transparent)

;; ---------------------------------------------------------------------------
;; 类型
;; ---------------------------------------------------------------------------

(define (scalar-type? t)
  (memq t '(b8 b16 b32 b64 s8 s16 s32 s64 ptr)))

(define (type->sexp t)
  (cond
    [(scalar-type? t) t]
    [(and (form? t) (eq? (car t) 'array))
     (list 'array (cadr t) (type->sexp (caddr t)))]
    [(and (form? t) (eq? (car t) 'struct-ref))
     (list 'struct-ref (cadr t))]
    [else (error 'struct-meta "bad type in metadata: ~e" t)]))

(define (type->source t)
  (cond
    [(scalar-type? t) t]
    [(and (form? t) (eq? (car t) 'array) (= 3 (length t)))
     (list 'array (cadr t) (type->source (caddr t)))]
    [(and (form? t) (eq? (car t) 'struct-ref) (= 2 (length t)))
     (cadr t)]
    [else (error 'struct-meta "bad struct field type in metadata: ~e" t)]))

;; ---------------------------------------------------------------------------
;; sdef -> 元数据
;; ---------------------------------------------------------------------------

(define (field->sexp f)
  (list 'field
        (list 'name (field-name f))
        (list 'type (type->sexp (field-type f)))
        (list 'offset (field-offset f))
        (list 'size (field-size f))
        (list 'align (field-align f))))

(define (padding->sexp p)
  (cond
    [(align-item? p)
     (list 'align
           (list 'n (align-item-n p))
           (list 'offset (align-item-offset p))
           (list 'size (align-item-size p)))]
    [(pad-item? p)
     (list 'pad
           (list 'n (pad-item-n p))
           (list 'offset (pad-item-offset p))
           (list 'size (pad-item-size p)))]
    [else (error 'struct-meta "bad padding item: ~e" p)]))

(define (sdef->sexp d)
  (list 'struct-def
        (list 'name (sdef-name d))
        (list 'size (sdef-size d))
        (list 'align (sdef-align d))
        (cons 'fields (map field->sexp (sdef-fields d)))
        (cons 'padding (map padding->sexp (sdef-padding d)))))

;; ---------------------------------------------------------------------------
;; 布局项顺序 / 声明
;; ---------------------------------------------------------------------------

(define (layout-item-offset it)
  (cond
    [(field? it) (field-offset it)]
    [(align-item? it) (align-item-offset it)]
    [(pad-item? it) (pad-item-offset it)]
    [else (error 'struct-meta "bad layout item: ~e" it)]))

(define (ordered-layout-items fields padding)
  (define indexed
    (for/list ([it (in-list (append fields padding))]
               [i (in-naturals)])
      (cons i it)))
  (map cdr
       (sort indexed
             (lambda (a b)
               (define oa (layout-item-offset (cdr a)))
               (define ob (layout-item-offset (cdr b)))
               (or (< oa ob) (and (= oa ob) (< (car a) (car b))))))))

(define (layout-item->decl item)
  (cond
    [(field? item)
     (list (field-name item) (type->source (field-type item)))]
    [(align-item? item)
     (list 'align (align-item-n item))]
    [(pad-item? item)
     (list 'pad (pad-item-n item))]
    [else (error 'struct-meta "bad layout item: ~e" item)]))

;; 布局无关的 struct 声明：没有 size / offset / align 结果。
(define (sdef->decl d)
  (cons 'struct
        (cons (sdef-name d)
              (map layout-item->decl
                   (ordered-layout-items (sdef-fields d) (sdef-padding d))))))

;; ---------------------------------------------------------------------------
;; 元数据 -> sdef
;; ---------------------------------------------------------------------------

(define (struct-def-form? x)
  (and (form? x) (eq? (car x) 'struct-def)))

(define (meta-nonnegative who n)
  (unless (exact-nonnegative-integer? n)
    (error 'struct-meta "~a 必须是非负整数: ~e" who n))
  n)

(define (meta-align who n)
  (unless (and (exact-positive-integer? n)
               (zero? (bitwise-and n (sub1 n))))
    (error 'struct-meta "~a 必须是 2 的正整数次幂: ~e" who n))
  n)

(define (metadata-type t)
  (cond
    [(scalar-type? t) t]
    [(and (form? t) (eq? (car t) 'array) (= 3 (length t))
          (exact-nonnegative-integer? (cadr t)))
     (list 'array (cadr t) (metadata-type (caddr t)))]
    [(and (form? t) (eq? (car t) 'struct-ref) (= 2 (length t))
          (path? (cadr t)))
     t]
    [else (error 'struct-meta "struct 字段类型非法: ~e" t)]))

(define (parse-field f)
  (unless (and (form? f) (eq? (car f) 'field))
    (error 'struct-meta "fields 里只能是 field: ~e" f))
  (define name (tag-ref 'struct-meta f 'name))
  (unless (symbol? name)
    (error 'struct-meta "field 名字必须是 symbol: ~e" name))
  (field name
         (metadata-type (tag-ref 'struct-meta f 'type))
         (meta-nonnegative 'field-offset (tag-ref 'struct-meta f 'offset))
         (meta-nonnegative 'field-size (tag-ref 'struct-meta f 'size))
         (meta-align 'field-align (tag-ref 'struct-meta f 'align))))

(define (parse-padding p)
  (unless (and (form? p) (memq (car p) '(align pad)))
    (error 'struct-meta "padding 里只能是 align/pad: ~e" p))
  (define n (meta-nonnegative 'padding-n (tag-ref 'struct-meta p 'n)))
  (define offset (meta-nonnegative 'padding-offset (tag-ref 'struct-meta p 'offset)))
  (define size (meta-nonnegative 'padding-size (tag-ref 'struct-meta p 'size)))
  (if (eq? (car p) 'align)
      (align-item (meta-align 'align-n n) offset size)
      (pad-item n offset size)))

(define (parse-sdef x)
  (unless (struct-def-form? x)
    (error 'struct-meta "not a struct-def: ~e" x))
  (define name (tag-ref 'struct-meta x 'name))
  (unless (path? name)
    (error 'struct-meta "struct 名字必须是链: ~e" name))
  (define size (meta-nonnegative 'struct-size (tag-ref 'struct-meta x 'size)))
  (define align (meta-align 'struct-align (tag-ref 'struct-meta x 'align)))
  (define fields-row (assq 'fields (cdr x)))
  (define padding-row (assq 'padding (cdr x)))
  (define fields (if fields-row (map parse-field (cdr fields-row)) '()))
  (define padding (if padding-row (map parse-padding (cdr padding-row)) '()))
  (sdef name fields (ordered-layout-items fields padding) padding size align))

;; ---------------------------------------------------------------------------
;; 输入容器
;; ---------------------------------------------------------------------------

(define (extern-struct-defs datum)
  (cond
    [(null? datum) '()]
    [(struct-def-form? datum) (list datum)]
    [(and (form? datum) (eq? (car datum) 'structs))
     (for/list ([x (in-list (cdr datum))])
       (unless (struct-def-form? x)
         (error 'struct-meta "(structs ...) 里只能是 struct-def: ~e" x))
       x)]
    [(and (form? datum) (eq? (car datum) 'build))
     (define row (assq 'structs (cdr datum)))
     (if row (extern-struct-defs (cons 'structs (cdr row))) '())]
    [(and (list? datum) (andmap struct-def-form? datum)) datum]
    [(and (list? datum)
          (andmap (lambda (x)
                    (or (struct-def-form? x)
                        (and (form? x) (memq (car x) '(structs build)))))
                  datum))
     (append* (for/list ([x (in-list datum)]) (extern-struct-defs x)))]
    [else
     (error 'struct-meta
            "extern-structs 只接受 (build ...) / (structs ...) / struct-def 列表: ~e"
            datum)]))
