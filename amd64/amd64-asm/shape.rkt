#lang racket
;;; amd64/amd64-asm/shape.rkt
;;;
;;; Generic s-expression shape: form / name / chain / address expression.
;;; No amd64-specific operand knowledge lives here.

(provide form?
         name?
         path?
         normalize-path
         as-items
         arith-head?
         arith-form?
         address-op-head?
         address-op-form?
         current-ip?
         address-expr?
         address-expr-chains
         eval-address)

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

;; 地址表达式里的位运算。它们和 +/− 一样在 layout/bind/encode 时求值。
(define (address-op-head? x)
  (and (form? x)
       (memq (car x) '(bitwise-and bitwise-ior ash bitwise-bit-field))))

(define (address-op-form? x)
  (and (address-op-head? x)
       (case (car x)
         [(ash) (= 3 (length x))]
         [(bitwise-bit-field) (= 4 (length x))]
         [else #t])
       (andmap address-expr? (cdr x))))

;; 地址表达式里的当前 IP。origin 是 item 的绝对地址；由 layout/bind/encode
;; 在求值时通过 HERE 传入。
(define (current-ip? x) (eq? x '$))

(define (address-expr? x)
  (cond
    [(exact-integer? x) #t]
    [(current-ip? x) #t]
    [(arith-head? x) (arith-form? x)]
    [(address-op-head? x) (address-op-form? x)]
    [(path? x) #t]
    [else #f]))

(define (address-expr-chains x)
  (remove-duplicates
   (cond
     [(exact-integer? x) '()]
     [(current-ip? x) '()]
     [(or (arith-head? x) (address-op-head? x))
      (append* (for/list ([a (in-list (cdr x))]) (address-expr-chains a)))]
     [else (list x)])))

(define (resolve-current-ip here)
  (or here
      (error 'eval-address "current-ip expression needs an origin address")))

(define (eval-address expr resolve [here #f])
  (cond
    [(exact-integer? expr) expr]
    [(current-ip? expr) (resolve-current-ip here)]
    [(arith-head? expr)
     (define vals (for/list ([a (in-list (cdr expr))])
                    (eval-address a resolve here)))
     (if (eq? (car expr) '+)
         (apply + vals)
         (- (car vals) (apply + (cdr vals))))]
    [(address-op-head? expr)
     (define vals (for/list ([a (in-list (cdr expr))])
                    (eval-address a resolve here)))
     (case (car expr)
       [(bitwise-and) (apply bitwise-and vals)]
       [(bitwise-ior) (apply bitwise-ior vals)]
       [(ash) (apply arithmetic-shift vals)]
       [(bitwise-bit-field) (apply bitwise-bit-field vals)])]
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
