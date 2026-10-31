#lang racket
;;; amd64/sexp.rkt
;;;
;;; amd64 后端的共享 s-expression 形状。
;;;
;;; 这里没有层语义: form / name / path / 地址表达式，以及 amd64 内存操作数的
;;; 形状。内存宽度统一用 b8 / b16 / b32 / b64。

(provide form?
         name?
         path?
         normalize-path
         as-items
         arith-head?
         arith-form?
         address-expr?
         address-expr-chains
         eval-address

         mem-form?
         parse-mem
         (struct-out mem))

;; ---------------------------------------------------------------------------
;; 通用形状
;; ---------------------------------------------------------------------------

(define (form? x) (and (pair? x) (list? x)))
(define (name? x) (or (symbol? x) (string? x) (number? x)))
(define (path? x) (and (list? x) (pair? x) (andmap name? x)))

(define (normalize-path x)
  (cond
    [(path? x) x]
    [(name? x) (list x)]
    [else #f]))

(define (arith-head? x) (and (form? x) (memq (car x) '(+ -))))
(define (arith-form? x) (and (arith-head? x) (>= (length x) 3) (andmap address-expr? (cdr x))))

(define (address-expr? x)
  (cond
    [(exact-integer? x) #t]
    [(arith-head? x) (arith-form? x)]
    [(path? x) #t]
    [else #f]))

(define (address-expr-chains x)
  (remove-duplicates
   (cond
     [(exact-integer? x) '()]
     [(arith-head? x) (append* (for/list ([a (in-list (cdr x))]) (address-expr-chains a)))]
     [else (list x)])))

(define (eval-address expr resolve)
  (cond
    [(exact-integer? expr) expr]
    [(arith-head? expr)
     (define vals (for/list ([a (in-list (cdr expr))]) (eval-address a resolve)))
     (if (eq? (car expr) '+)
         (apply + vals)
         (- (car vals) (apply + (cdr vals))))]
    [else
     (define v (resolve expr))
     (or v (error 'eval-address "undefined symbol in address expression: ~s" expr))]))

(define (as-items prog)
  (define body
    (cond
      [(and (form? prog) (eq? (car prog) 'quote) (= 2 (length prog)) (list? (cadr prog)))
       (cadr prog)]
      [(list? prog) prog]
      [else (list prog)]))
  (define items
    (cond
      [(null? body) '()]
      [(pair? (car body)) body]
      [else (list body)]))
  (if (and (= 1 (length items)) (form? (car items)) (eq? (caar items) 'begin))
      (cdar items)
      items))

;; ---------------------------------------------------------------------------
;; 内存操作数
;;
;;   (b64 (base rax) (index rcx) (scale 4) (disp (+ (data) 8)) (seg fs))
;;
;; 缺省:
;;   base/index/seg 无
;;   disp 0
;;   index 存在时 scale 1
;; ---------------------------------------------------------------------------

(struct mem (width base index scale disp seg disp-width) #:transparent)

(define mem-heads '(b8 b16 b32 b64))
(define mem-field-keys '(base index scale disp seg))

(define (mem-head-width head)
  (case head
    [(b8) 8]
    [(b16) 16]
    [(b32) 32]
    [(b64) 64]
    [else #f]))

(define (mem-field? x)
  (and (form? x)
       (= 2 (length x))
       (memq (car x) mem-field-keys)))

(define (mem-form? x)
  (and (form? x)
       (memq (car x) mem-heads)
       (andmap mem-field? (cdr x))))

(define (parse-mem x)
  (unless (mem-form? x)
    (error 'parse-mem "expected b8/b16/b32/b64 memory operand: ~e" x))
  (define width (mem-head-width (car x)))
  (define fields (cdr x))
  (define names (map car fields))
  (unless (= (length names) (length (remove-duplicates names eq?)))
    (error 'parse-mem "duplicate memory field: ~e" x))
  (define (field key default)
    (cond ((assq key fields) => cadr)
          [else default]))
  (define base (field 'base #f))
  (define index (field 'index #f))
  (define scale (field 'scale 1))
  (define disp (field 'disp 0))
  (define seg (field 'seg #f))
  (unless (or (not base) (symbol? base))
    (error 'parse-mem "bad base register: ~e" base))
  (unless (or (not index) (symbol? index))
    (error 'parse-mem "bad index register: ~e" index))
  (unless (memq scale '(1 2 4 8))
    (error 'parse-mem "bad scale: ~e" scale))
  (unless (or (not seg) (memq seg '(fs gs)))
    (error 'parse-mem "bad segment override: ~e" seg))
  (unless (address-expr? disp)
    (error 'parse-mem "bad displacement expression: ~e" disp))
  (when (and (not index) (not (= scale 1)))
    (error 'parse-mem "scale requires an index register: ~e" x))
  (mem width base index scale disp seg
       (if (exact-integer? disp) 'auto 32)))
