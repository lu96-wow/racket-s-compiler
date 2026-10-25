#lang racket/base

;; ============================================================
;; frame / env / cont / call / tailcall / return 的形式层
;;
;; 只做语法、访问器、布局计算，不做 lowering。
;;
;; (frame
;;   (base fp)
;;   (link fp)
;;   (slots
;;     (slot0 (kind arg))
;;     (slot1 (kind local))
;;     (slot2 (kind spill))
;;     (slot3 (kind captured))))
;;
;; (env-ref dst (heap 0 2))
;; (env-set (heap 0 2) src)
;;
;; (cont K0 (code Lafter) (env fp))
;; (call f (args a0 a1) (cont K0))
;; (tailcall f (args a0 a1))
;; (return (a0))
;; ============================================================

(require racket/list
         racket/string
         "repr.rkt")

(provide frame-form?
         frame-base
         frame-link
         frame-slot-decls
         slot-decl?
         slot-decl-name
         slot-decl-kind
         slot-decl-repr
         slot-decl-index
         slot-kinds
         frame-slot-count
         frame-slot-offset
         frame-saved-offset
         frame-size
         frame-align

         heap-loc?
         heap-depth
         heap-index

         env-ref?
         env-ref-dst
         env-ref-loc
         env-set?
         env-set-loc
         env-set-src

         cont-form?
         cont-name
         cont-code
         cont-env
         cont-ref?

         args-form?
         values-form?
         call-form?
         call-target
         call-args
         call-cont
         tailcall-form?
         tailcall-target
         tailcall-args
         return-form?

         declaration-form?
         structured-form?
         form-tag?)

;; ------------------------------------------------------------
;; 常量
;; ------------------------------------------------------------

(define slot-kinds
  '(arg local spill captured saved outgoing))

;; frame 头部固定 16 字节：0 = old fp，8 = ra。
(define frame-header-size 16)

;; stack policy 先保存全部 callee-saved，保证调用正确。
;; 后面可以用“实际用到的 s* 集合”替换。
(define callee-saved-count 12)

(define frame-align 16)

(define (align-up n alignment)
  (* alignment (quotient (+ n (sub1 alignment)) alignment)))

;; ------------------------------------------------------------
;; frame
;; ------------------------------------------------------------

(define (frame-form? value)
  (and (list? value)
       (= (length value) 4)
       (eq? (car value) 'frame)
       (let ([base (cadr value)]
             [link (caddr value)]
             [slots (cadddr value)])
         (and (list? base)
              (= (length base) 2)
              (eq? (car base) 'base)
              (symbol? (cadr base))
              (list? link)
              (= (length link) 2)
              (eq? (car link) 'link)
              (symbol? (cadr link))
              (list? slots)
              (eq? (car slots) 'slots)
              (andmap slot-decl? (cdr slots))))))

(define (frame-base frame)
  (cadr (cadr frame)))

(define (frame-link frame)
  (cadr (caddr frame)))

(define (frame-slot-decls frame)
  (cdr (cadddr frame)))

(define (slot-decl? value)
  (and (list? value)
       (or (= (length value) 2)
           (= (length value) 3))
       (symbol? (car value))
       (let* ([name (symbol->string (car value))]
              [index (and (string-prefix? name "slot")
                          (string->number (substring name 4)))]
              [kind (cadr value)])
         (and (exact-nonnegative-integer? index)
              (list? kind)
              (= (length kind) 2)
              (eq? (car kind) 'kind)
              (memq (cadr kind) slot-kinds)
              (or (= (length value) 2)
                  (repr-form? (caddr value)))
              #t))))

(define (slot-decl-name decl)
  (car decl))

(define (slot-decl-kind decl)
  (cadr (cadr decl)))

;; 省略 (repr ...) 时默认 b64。
(define (slot-decl-repr decl)
  (cond
    [(= (length decl) 3) (cadr (caddr decl))]
    [else 'b64]))

(define (slot-decl-index decl)
  (string->number (substring (symbol->string (slot-decl-name decl)) 4)))

(define (frame-slot-count frame)
  (for/fold ([count 0]) ([decl (in-list (frame-slot-decls frame))])
    (max count (add1 (slot-decl-index decl)))))

(define (frame-slot-offset frame index)
  (unless (and (exact-nonnegative-integer? index)
               (< index (frame-slot-count frame)))
    (error 'frame-slot-offset "slot index out of range: ~a" index))
  (+ frame-header-size (* 8 index)))

;; s0..s11 放在 slot 区之后。
(define (frame-saved-offset frame index)
  (unless (and (exact-nonnegative-integer? index)
               (< index callee-saved-count))
    (error 'frame-saved-offset "saved register index out of range: ~a" index))
  (+ frame-header-size
     (* 8 (frame-slot-count frame))
     (* 8 index)))

(define (frame-size frame)
  (align-up (+ frame-header-size
               (* 8 (frame-slot-count frame))
               (* 8 callee-saved-count))
            frame-align))

;; ------------------------------------------------------------
;; heap location
;; ------------------------------------------------------------

(define (heap-loc? value)
  (and (list? value)
       (= (length value) 3)
       (eq? (car value) 'heap)
       (exact-nonnegative-integer? (cadr value))
       (exact-nonnegative-integer? (caddr value))))

(define (heap-depth loc)
  (cadr loc))

(define (heap-index loc)
  (caddr loc))

;; ------------------------------------------------------------
;; env-ref / env-set
;; ------------------------------------------------------------

(define (env-ref? value)
  (and (list? value)
       (= (length value) 3)
       (eq? (car value) 'env-ref)
       (symbol? (cadr value))
       (heap-loc? (caddr value))))

(define (env-ref-dst value)
  (cadr value))

(define (env-ref-loc value)
  (caddr value))

(define (env-set? value)
  (and (list? value)
       (= (length value) 3)
       (eq? (car value) 'env-set)
       (heap-loc? (cadr value))
       (symbol? (caddr value))))

(define (env-set-loc value)
  (cadr value))

(define (env-set-src value)
  (caddr value))

;; ------------------------------------------------------------
;; cont
;; ------------------------------------------------------------

;; 声明：(cont K0 (code Lafter) (env fp))
(define (cont-form? value)
  (and (list? value)
       (= (length value) 4)
       (eq? (car value) 'cont)
       (symbol? (cadr value))
       (let ([code (caddr value)]
             [env (cadddr value)])
         (and (list? code)
              (= (length code) 2)
              (eq? (car code) 'code)
              (symbol? (cadr code))
              (list? env)
              (= (length env) 2)
              (eq? (car env) 'env)
              (symbol? (cadr env))))))

(define (cont-name value) (cadr value))
(define (cont-code value) (cadr (caddr value)))
(define (cont-env value) (cadr (cadddr value)))

;; 引用：(cont K0)
(define (cont-ref? value)
  (and (list? value)
       (= (length value) 2)
       (eq? (car value) 'cont)
       (symbol? (cadr value))))

;; ------------------------------------------------------------
;; args / values
;; ------------------------------------------------------------

(define (args-form? value)
  (and (list? value)
       (pair? value)
       (eq? (car value) 'args)
       (andmap symbol? (cdr value))))

(define (values-form? value)
  (and (list? value)
       (andmap symbol? value)))

;; ------------------------------------------------------------
;; call / tailcall / return
;; ------------------------------------------------------------

(define (call-form? value)
  (and (list? value)
       (= (length value) 4)
       (eq? (car value) 'call)
       (symbol? (cadr value))
       (args-form? (caddr value))
       (cont-ref? (cadddr value))))

(define (call-target value) (cadr value))
(define (call-args value) (cdr (caddr value)))
(define (call-cont value) (cadr (cadddr value)))

(define (tailcall-form? value)
  (and (list? value)
       (= (length value) 3)
       (eq? (car value) 'tailcall)
       (symbol? (cadr value))
       (args-form? (caddr value))))

(define (tailcall-target value) (cadr value))
(define (tailcall-args value) (cdr (caddr value)))

(define (return-form? value)
  (and (list? value)
       (= (length value) 2)
       (eq? (car value) 'return)
       (values-form? (cadr value))))

;; ------------------------------------------------------------
;; tag 分类
;; ------------------------------------------------------------

(define (form-tag? tag)
  (memq tag '(frame slots slot kind base link heap
              struct field
              env-ref env-set
              cont code env args
              call tailcall return)))

;; 声明不是指令：frame / cont 以及它们的子形式。
(define (declaration-form? value)
  (and (list? value)
       (pair? value)
       (let ([tag (car value)])
         (memq tag '(frame slots slot kind base link heap
                     struct field
                     cont code env args)))))

;; 所有结构化 tag（声明 + 伪指令）。
(define (structured-form? value)
  (and (list? value)
       (pair? value)
       (form-tag? (car value))))
