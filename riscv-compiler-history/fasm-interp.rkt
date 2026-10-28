#lang racket/base

;; ============================================================
;; F-asm reference interpreter
;;
;; 语义要点：
;;   - heap frame + lexical link
;;   - closure = { code, env, arity }
;;   - continuation = { code, env, next }  （链式！）
;;   - 参数/返回值 = 一个 value vector（argv）；没有真实寄存器 ABI
;;   - call  = 用给定 continuation
;;   - tailcall = 保持当前 continuation
;;   - return = 跳到当前 continuation，并恢复 k = cont.next
;;
;; 先把语义跑通；GC 暂时不做（heap 只增不减）。
;; ============================================================

(require racket/list
         racket/match
         "fasm.rkt")

(provide run-fasm
         run-fasm-raw)

;; ------------------------------------------------------------
;; host 侧的特殊对象
;; ------------------------------------------------------------

(struct halt ())

(define HALT (halt))

;; ------------------------------------------------------------
;; heap
;; ------------------------------------------------------------

(define (make-empty-heap)
  (make-vector 1024 #f))

(define (heap-grow! heap count)
  (let* ([old (vector-length heap)]
         [new (make-vector (* 2 old) #f)])
    (vector-copy! new 0 heap 0 count)
    new))

;; ------------------------------------------------------------
;; 汇编：label -> pc
;; ------------------------------------------------------------

(define (assemble items)
  (define labels (make-hash))
  (define code '())
  (define pc 0)
  (for ([item (in-list items)])
    (cond
      [(fasm-label? item)
       (hash-set! labels (fasm-label-name item) pc)]
      [else
       (set! code (cons item code))
       (set! pc (add1 pc))]))
  (values (list->vector (reverse code)) labels))

;; ------------------------------------------------------------
;; 主解释器
;; ------------------------------------------------------------

(define (run-fasm* program #:trace? [trace? #f])
  (define items (fasm-items program))
  (define-values (code labels) (assemble items))

  (define heap (make-empty-heap))
  (define heap-count 0)
  (define symbol-table (make-hash))
  (define regs (make-hash))
  (define fp #f)
  (define argv #())          ; incoming value vector（参数或返回值）
  (define pc 0)
  (define halted? #f)
  (define result NIL)

  ;; ----------------------------------------------------------
  ;; heap 基础
  ;; ----------------------------------------------------------

  (define (heap-alloc! obj)
    (when (= heap-count (vector-length heap))
      (set! heap (heap-grow! heap heap-count)))
    (define idx heap-count)
    (vector-set! heap idx obj)
    (set! heap-count (add1 heap-count))
    idx)

  (define (heap-ref idx)
    (unless (and (exact-nonnegative-integer? idx)
                 (< idx heap-count))
      (error 'fasm "bad heap index: ~a" idx))
    (vector-ref heap idx))

  (define (make-frame! link size)
    (heap-alloc! (vector 'frame link (make-vector size NIL))))

  (define (frame-object idx)
    (define obj (heap-ref idx))
    (unless (eq? (vector-ref obj 0) 'frame)
      (error 'fasm "not a frame: ~a" idx))
    obj)

  (define (frame-link idx)
    (vector-ref (frame-object idx) 1))

  (define (frame-slots idx)
    (vector-ref (frame-object idx) 2))

  (define (walk-frame idx depth)
    (cond
      [(zero? depth) idx]
      [else
       (define link (frame-link idx))
       (unless link
         (error 'fasm "environment depth ~a exceeds frame chain" depth))
       (walk-frame link (sub1 depth))]))

  (define (env-ref idx depth index)
    (define slots (frame-slots (walk-frame idx depth)))
    (unless (< index (vector-length slots))
      (error 'fasm "env slot out of range: ~a" index))
    (vector-ref slots index))

  (define (env-set! idx depth index value)
    (define slots (frame-slots (walk-frame idx depth)))
    (unless (< index (vector-length slots))
      (error 'fasm "env slot out of range: ~a" index))
    (vector-set! slots index value))

  ;; ----------------------------------------------------------
  ;; 值构造
  ;; ----------------------------------------------------------

  (define (make-closure! code env arity)
    (make-pointer
     (heap-alloc! (vector 'closure code env arity))
     TAG-PROCEDURE))

  (define (make-continuation! code env next)
    (make-pointer
     (heap-alloc! (vector 'continuation code env next))
     TAG-PROCEDURE))

  (define (make-pair! car-value cdr-value)
    (make-pointer
     (heap-alloc! (vector 'pair car-value cdr-value))
     TAG-CONS))

  (define (make-box! value)
    (make-pointer
     (heap-alloc! (vector 'box value))
     TAG-VECTOR))

  (define (make-string! str)
    (make-pointer
     (heap-alloc! (vector 'string str))
     TAG-STRING))

  (define (make-vector-value! values)
    (make-pointer
     (heap-alloc! (vector 'vector values))
     TAG-VECTOR))

  (define (intern-symbol! name)
    (or (hash-ref symbol-table name #f)
        (let ([value (make-pointer
                      (heap-alloc! (vector 'symbol name))
                      TAG-SYMBOL)])
          (hash-set! symbol-table name value)
          value)))

  (define (heap-object value tag)
    (unless (and (exact? value) (= (tag-of value) tag))
      (error 'fasm "unexpected value tag: ~a" value))
    (heap-ref (pointer-index value)))

  (define (pair-value? value)
    (and (exact? value) (= (tag-of value) TAG-CONS)))

  (define (symbol-value? value)
    (and (exact? value) (= (tag-of value) TAG-SYMBOL)))

  (define (string-value? value)
    (and (exact? value) (= (tag-of value) TAG-STRING)))

  (define (procedure-value? value)
    (and (exact? value) (= (tag-of value) TAG-PROCEDURE)))

  (define (vector-object? value)
    (and (exact? value)
         (= (tag-of value) TAG-VECTOR)
         (eq? (vector-ref (heap-object value TAG-VECTOR) 0) 'vector)))

  (define (box-value? value)
    (and (exact? value)
         (= (tag-of value) TAG-VECTOR)
         (eq? (vector-ref (heap-object value TAG-VECTOR) 0) 'box)))

  ;; ----------------------------------------------------------
  ;; literal
  ;; ----------------------------------------------------------

  (define (nil-literal? lit)
    (or (eq? lit 'nil)
        (null? lit)
        (equal? lit '(quote nil))))

  (define (literal->value lit)
    (cond
      [(boolean? lit) (if lit TRUE FALSE)]
      [(exact-integer? lit) (encode-fixnum lit)]
      [(char? lit) (encode-char lit)]
      [(string? lit) (make-string! lit)]
      [(nil-literal? lit) NIL]
      [(and (list? lit)
            (= (length lit) 2)
            (eq? (car lit) 'quote))
       (define datum (cadr lit))
       (cond
         [(nil-literal? datum) NIL]
         [(symbol? datum) (intern-symbol! datum)]
         [else
          (error 'fasm "unsupported quoted literal: ~a" datum)])]
      [else
       (error 'fasm "unsupported literal: ~a" lit)]))

  ;; ----------------------------------------------------------
  ;; 寄存器
  ;; ----------------------------------------------------------

  (define (get-reg name)
    (hash-ref regs name
              (lambda ()
                (error 'fasm "read uninitialized register: ~a" name))))

  (define (set-reg! name value)
    (hash-set! regs name value))

  (define (require-value-vector who value)
    (unless (vector? value)
      (error who "expected value vector, got: ~a" value))
    value)

  ;; ----------------------------------------------------------
  ;; 应用
  ;; ----------------------------------------------------------

  (define (label-pc label)
    (or (hash-ref labels label #f)
        (error 'fasm "undefined label: ~a" label)))

  (define (apply-procedure! fval args kval)
    (define vec (require-value-vector 'apply args))
    (cond
      [(not (exact? fval))
       (error 'fasm "apply: not a procedure: ~a" fval)]
      [(not (= (tag-of fval) TAG-PROCEDURE))
       (error 'fasm "apply: not a procedure: ~a" fval)]
      [else
       (define obj (heap-object fval TAG-PROCEDURE))
       (case (vector-ref obj 0)
         [(closure)
          (define code (vector-ref obj 1))
          (define env (vector-ref obj 2))
          (define arity (vector-ref obj 3))
          (unless (= (vector-length vec) arity)
            (error 'fasm
                   "arity mismatch for ~a: expected ~a, got ~a"
                   code arity (vector-length vec)))
          (set! argv vec)
          (set-reg! 'k kval)
          (set! fp env)
          (set! pc (label-pc code))]

         [(continuation)
          ;; 调用 continuation 忽略当前 continuation，恢复它自己的 next。
          (unless (= (vector-length vec) 1)
            (error 'fasm "continuation expects 1 value, got ~a" (vector-length vec)))
          (set! argv vec)
          (set! fp (vector-ref obj 2))
          (set! pc (label-pc (vector-ref obj 1)))
          (set-reg! 'k (vector-ref obj 3))]

         [else
          (error 'fasm "unknown procedure object: ~a" obj)])]))

  ;; 返回值向量交给当前 continuation。
  (define (return-values! vec)
    (define kval (get-reg 'k))
    (cond
      [(halt? kval)
       (set! halted? #t)
       (set! result (if (zero? (vector-length vec))
                        NIL
                        (vector-ref vec 0)))]
      [else
       (define obj (heap-object kval TAG-PROCEDURE))
       (set! argv vec)
       (set! fp (vector-ref obj 2))
       (set! pc (label-pc (vector-ref obj 1)))
       (set-reg! 'k (vector-ref obj 3))]))

  ;; ----------------------------------------------------------
  ;; display
  ;; ----------------------------------------------------------

  (define (display-value value)
    (cond
      [(fixnum? value) (display (decode-fixnum value))]
      [(boolean-value? value) (display (if (= value TRUE) "#t" "#f"))]
      [(nil-value? value) (display "()")]
      [(char-value? value) (display (decode-char value))]
      [else
       (case (tag-of value)
         [(3) (display (vector-ref (heap-ref (pointer-index value)) 1))]
         [(4) (display (vector-ref (heap-ref (pointer-index value)) 1))]
         [(2)
          (define obj (heap-ref (pointer-index value)))
          (display "(")
          (let loop ([v value])
            (cond
              [(pair-value? v)
               (define o (heap-ref (pointer-index v)))
               (display-value (vector-ref o 1))
               (define rest (vector-ref o 2))
               (cond
                 [(nil-value? rest) (void)]
                 [(pair-value? rest) (display " ") (loop rest)]
                 [else (display " . ") (display-value rest)])]
              [else (display-value v)]))
          (display ")")]
         [(5)
          (define obj (heap-ref (pointer-index value)))
          (case (vector-ref obj 0)
            [(box) (display "#&") (display-value (vector-ref obj 1))]
            [(vector)
             (display "#(")
             (for ([v (in-list (vector->list (vector-ref obj 1)))]
                   [i (in-naturals)])
               (when (> i 0) (display " "))
               (display-value v))
             (display ")")]
            [else (display "#<vector>")])]
         [(6)
          (define obj (heap-ref (pointer-index value)))
          (display (case (vector-ref obj 0)
                     [(closure) "#<procedure>"]
                     [(continuation) "#<continuation>"]
                     [else "#<procedure>"]))]
         [else (display value)])]))

  ;; ----------------------------------------------------------
  ;; primitive
  ;; ----------------------------------------------------------

  (define (bool->value b) (if b TRUE FALSE))

  (define (check-fixnum who value)
    (unless (fixnum? value)
      (error who "expected fixnum, got: ~a" value))
    (decode-fixnum value))

  (define (primitive! name operands)
    (match (cons name operands)
      [(list 'add dst a b)
       (set-reg! dst (encode-fixnum (+ (check-fixnum 'add (get-reg a))
                                       (check-fixnum 'add (get-reg b)))))]
      [(list 'sub dst a b)
       (set-reg! dst (encode-fixnum (- (check-fixnum 'sub (get-reg a))
                                       (check-fixnum 'sub (get-reg b)))))]
      [(list 'mul dst a b)
       (set-reg! dst (encode-fixnum (* (check-fixnum 'mul (get-reg a))
                                       (check-fixnum 'mul (get-reg b)))))]
      [(list 'div dst a b)
       (set-reg! dst (encode-fixnum (quotient (check-fixnum 'div (get-reg a))
                                              (check-fixnum 'div (get-reg b)))))]
      [(list 'mod dst a b)
       (set-reg! dst (encode-fixnum (modulo (check-fixnum 'mod (get-reg a))
                                            (check-fixnum 'mod (get-reg b)))))]
      [(list 'eq? dst a b)
       (set-reg! dst (bool->value (eq? (get-reg a) (get-reg b))))]
      [(list 'lt dst a b)
       (set-reg! dst (bool->value (< (check-fixnum 'lt (get-reg a))
                                     (check-fixnum 'lt (get-reg b)))))]
      [(list 'le dst a b)
       (set-reg! dst (bool->value (<= (check-fixnum 'le (get-reg a))
                                      (check-fixnum 'le (get-reg b)))))]
      [(list 'gt dst a b)
       (set-reg! dst (bool->value (> (check-fixnum 'gt (get-reg a))
                                     (check-fixnum 'gt (get-reg b)))))]
      [(list 'ge dst a b)
       (set-reg! dst (bool->value (>= (check-fixnum 'ge (get-reg a))
                                      (check-fixnum 'ge (get-reg b)))))]
      [(list 'cons dst a b)
       (set-reg! dst (make-pair! (get-reg a) (get-reg b)))]
      [(list 'car dst p)
       (define v (get-reg p))
       (unless (pair-value? v) (error 'car "not a pair: ~a" v))
       (set-reg! dst (vector-ref (heap-object v TAG-CONS) 1))]
      [(list 'cdr dst p)
       (define v (get-reg p))
       (unless (pair-value? v) (error 'cdr "not a pair: ~a" v))
       (set-reg! dst (vector-ref (heap-object v TAG-CONS) 2))]
      [(list 'null? dst v)
       (set-reg! dst (bool->value (nil-value? (get-reg v))))]
      [(list 'pair? dst v)
       (set-reg! dst (bool->value (pair-value? (get-reg v))))]
      [(list 'procedure? dst v)
       (set-reg! dst (bool->value (procedure-value? (get-reg v))))]
      [(list 'fixnum? dst v)
       (set-reg! dst (bool->value (fixnum? (get-reg v))))]
      [(list 'boolean? dst v)
       (set-reg! dst (bool->value (boolean-value? (get-reg v))))]
      [(list 'symbol? dst v)
       (set-reg! dst (bool->value (symbol-value? (get-reg v))))]
      [(list 'string? dst v)
       (set-reg! dst (bool->value (string-value? (get-reg v))))]
      [(list 'vector? dst v)
       (set-reg! dst (bool->value (vector-object? (get-reg v))))]
      [(list 'box? dst v)
       (set-reg! dst (bool->value (box-value? (get-reg v))))]
      [(list 'box dst v)
       (set-reg! dst (make-box! (get-reg v)))]
      [(list 'unbox dst b)
       (define v (get-reg b))
       (unless (box-value? v) (error 'unbox "not a box: ~a" v))
       (set-reg! dst (vector-ref (heap-object v TAG-VECTOR) 1))]
      [(list 'set-box! dst b v)
       (define box (get-reg b))
       (unless (box-value? box) (error 'set-box! "not a box: ~a" box))
       (vector-set! (heap-object box TAG-VECTOR) 1 (get-reg v))
       (set-reg! dst NIL)]
      [(list 'display v)
       (display-value (get-reg v))
       (flush-output)]
      [(list 'newline)
       (newline)
       (flush-output)]
      [(list 'call/cc f)
       (define k0 (get-reg 'k))
       (apply-procedure! (get-reg f) (vector k0) k0)]
      [(list 'halt)
       (set! halted? #t)
       (set! result NIL)]
      [else
       (error 'fasm "unknown primitive: ~a" (cons name operands))]))

  ;; ----------------------------------------------------------
  ;; 初始化
  ;; ----------------------------------------------------------

  (set! fp (make-frame! #f 0))      ; global frame
  (set-reg! 'k HALT)
  (set! pc (label-pc 'main))

  ;; ----------------------------------------------------------
  ;; 单步执行
  ;; ----------------------------------------------------------

  (define (step!)
    (define insn (vector-ref code pc))
    (when trace?
      (eprintf "; pc=~a fp=~a insn=~s\n" pc fp insn))
    (match insn
      [(list 'label _)
       (error 'fasm "label reached execution: ~a" insn)]

      [(list 'alloc-frame n)
       (set! fp (make-frame! fp n))
       (set! pc (add1 pc))]

      [(list 'const dst lit)
       (set-reg! dst (literal->value lit))
       (set! pc (add1 pc))]

      [(list 'env-ref dst (list 'env depth index))
       (set-reg! dst (env-ref fp depth index))
       (set! pc (add1 pc))]

      [(list 'env-set (list 'env depth index) src)
       (env-set! fp depth index (get-reg src))
       (set! pc (add1 pc))]

      [(list 'closure dst code arity)
       (set-reg! dst (make-closure! code fp arity))
       (set! pc (add1 pc))]

      [(list 'cont dst code)
       ;; 新 continuation 的 next 是当前 k；如果 dst 就是 k，
       ;; 先读旧值再写，链不会断。
       (set-reg! dst (make-continuation! code fp (get-reg 'k)))
       (set! pc (add1 pc))]

      [(list 'move dst src)
       (set-reg! dst (get-reg src))
       (set! pc (add1 pc))]

      ;; 语法糖：直接列出 args / return values。
      [(list 'call f (list 'args arg-regs ...) (list 'cont kreg))
       (apply-procedure! (get-reg f)
                         (list->vector (map get-reg arg-regs))
                         (get-reg kreg))]

      ;; 纯形式：参数是一个 value vector。
      [(list 'call f argv-reg (list 'cont kreg))
       (apply-procedure! (get-reg f)
                         (require-value-vector 'call (get-reg argv-reg))
                         (get-reg kreg))]

      [(list 'tailcall f (list 'args arg-regs ...))
       (apply-procedure! (get-reg f)
                         (list->vector (map get-reg arg-regs))
                         (get-reg 'k))]

      [(list 'tailcall f argv-reg)
       (apply-procedure! (get-reg f)
                         (require-value-vector 'tailcall (get-reg argv-reg))
                         (get-reg 'k))]

      [(list 'return (list vals ...))
       (return-values! (list->vector (map get-reg vals)))]

      [(list 'return vals-reg)
       (return-values! (require-value-vector 'return (get-reg vals-reg)))]

      [(list 'jump label)
       (set! pc (label-pc label))]

      [(list 'branch-if reg label)
       (define v (get-reg reg))
       (set! pc (if (eq? v FALSE)
                    (add1 pc)
                    (label-pc label)))]

      [(list 'branch-if-not reg label)
       (define v (get-reg reg))
       (set! pc (if (eq? v FALSE)
                    (label-pc label)
                    (add1 pc)))]

      [(list 'pack dst regs ...)
       (set-reg! dst (list->vector (map get-reg regs)))
       (set! pc (add1 pc))]

      [(list 'arg-ref dst index)
       (unless (< index (vector-length argv))
         (error 'fasm "arg-ref out of range: ~a" index))
       (set-reg! dst (vector-ref argv index))
       (set! pc (add1 pc))]

      [(list 'arg-count dst)
       (set-reg! dst (encode-fixnum (vector-length argv)))
       (set! pc (add1 pc))]

      [(list 'prim name operands ...)
       (define jumped? (eq? name 'call/cc))
       (primitive! name operands)
       (unless (or halted? jumped?)
         (set! pc (add1 pc)))]

      [(list 'safepoint _)
       (set! pc (add1 pc))]

      [(list 'halt)
       (set! halted? #t)
       (set! result NIL)]

      [else
       (error 'fasm "unknown instruction: ~a" insn)]))

  ;; ----------------------------------------------------------
  ;; 主循环：host 栈恒定
  ;; ----------------------------------------------------------

  (let loop ()
    (cond
      [halted? (values result heap)]
      [(>= pc (vector-length code))
       (error 'fasm "pc out of range: ~a" pc)]
      [else
       (step!)
       (loop)])))

;; ------------------------------------------------------------
;; host 表示
;; ------------------------------------------------------------

(define (raw-value->host value heap)
  (define (heap-ref idx) (vector-ref heap idx))
  (define (obj v) (heap-ref (pointer-index v)))
  (cond
    [(fixnum? value) (decode-fixnum value)]
    [(boolean-value? value) (= value TRUE)]
    [(nil-value? value) '()]
    [(char-value? value) (decode-char value)]
    [else
     (case (tag-of value)
       [(3) (vector-ref (obj value) 1)]
       [(4) (vector-ref (obj value) 1)]
       [(2)
        (define o (obj value))
        (cons (raw-value->host (vector-ref o 1) heap)
              (raw-value->host (vector-ref o 2) heap))]
       [(5)
        (define o (obj value))
        (case (vector-ref o 0)
          [(box) (box (raw-value->host (vector-ref o 1) heap))]
          [(vector)
           (for/vector ([v (in-list (vector->list (vector-ref o 1)))])
             (raw-value->host v heap))]
          [else value])]
       [(6)
        (define o (obj value))
        (case (vector-ref o 0)
          [(closure) 'procedure]
          [(continuation) 'continuation]
          [else value])]
       [else value])]))

(define (run-fasm-raw program #:trace? [trace? #f])
  (define-values (raw _heap) (run-fasm* program #:trace? trace?))
  raw)

(define (run-fasm program #:trace? [trace? #f])
  (define-values (raw heap) (run-fasm* program #:trace? trace?))
  (raw-value->host raw heap))
