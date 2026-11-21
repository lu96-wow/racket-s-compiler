#lang racket
;;; ir/verify.rkt
;;;
;;; virtual IR 的验证。只检查：
;;;   - 顶层只有 func；
;;;   - vregs / alloc / entry / block / term / op 的形状；
;;;   - 名字声明和引用；
;;;   - virtual IR 里没有 native / slot / label / j / b / C ABI 名字。
;;;
;;; 它不检查：
;;;   - CFG 可达性（Step 2）；
;;;   - 寄存器分配；
;;;   - 指令选择 / 布局 / 编码。

(require racket/list
         "../core/sexp.rkt"
         "shape.rkt")

(provide verify-virtual
         verify-virtual-program
         verify-virtual-func)

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (verify-virtual-program program)
  (unless (list? program)
    (error 'verify-virtual "program must be a proper list: ~e" program))
  (for ([item (in-list program)])
    (unless (and (tagged? item 'func))
      (error 'verify-virtual "virtual program top level only accepts func: ~e" item))
    (verify-func item))
  program)

(define verify-virtual verify-virtual-program)

(define (verify-virtual-func form)
  (verify-func form)
  form)

;; ---------------------------------------------------------------------------
;; 函数
;; ---------------------------------------------------------------------------

(define (verify-func form)
  (unless (and (tagged? form 'func)
               (>= (length form) 2)
               (chain? (cadr form)))
    (error 'verify-virtual "malformed func: ~e" form))

  (define func-name (cadr form))
  (define body (cddr form))

  (define vregs-form #f)
  (define alloc-form #f)
  (define entry-form #f)
  (define block-forms '())

  (for ([it (in-list body)])
    (cond
      [(tagged? it 'vregs)
       (when vregs-form
         (fail func-name "more than one vregs form"))
       (set! vregs-form it)]
      [(tagged? it 'alloc)
       (when alloc-form
         (fail func-name "more than one alloc form"))
       (set! alloc-form it)]
      [(tagged? it 'entry)
       (when entry-form
         (fail func-name "more than one entry form"))
       (set! entry-form it)]
      [(tagged? it 'block)
       (set! block-forms (cons it block-forms))]
      [else
       (fail func-name "unexpected form in func body: ~e" it)]))

  (unless vregs-form
    (fail func-name "missing (vregs ...) form"))
  (unless entry-form
    (fail func-name "missing (entry ...) form"))

  (define vregs (parse-vregs func-name vregs-form))
  (when alloc-form
    (parse-alloc func-name alloc-form vregs))

  (define ordered-blocks (reverse block-forms))
  (define blocks (parse-blocks func-name ordered-blocks))
  (when (zero? (hash-count blocks))
    (fail func-name "function has no blocks"))

  (define entry (parse-entry func-name entry-form))
  (unless (hash-has-key? blocks entry)
    (fail func-name "entry block ~a is not declared" entry))

  (for ([block-form (in-list ordered-blocks)])
    (verify-block func-name block-form vregs blocks))

  (void))

;; ---------------------------------------------------------------------------
;; vregs
;; ---------------------------------------------------------------------------

(define (parse-vregs func-name form)
  (unless (tagged? form 'vregs)
    (fail func-name "malformed vregs form: ~e" form))
  (define table (make-hash))
  (for ([decl (in-list (cdr form))])
    (unless (vreg-decl? decl)
      (fail func-name "malformed vreg declaration: ~e" decl))
    (define vreg (car decl))
    (when (hash-has-key? table vreg)
      (fail func-name "vreg ~a is declared twice" (vreg->string vreg)))
    (check-vreg-options func-name decl)
    (hash-set! table vreg decl))
  table)

(define (check-vreg-options func-name decl)
  (define seen (make-hash))
  (for ([option (in-list (vreg-decl-options decl))])
    (define head (car option))
    (when (hash-has-key? seen head)
      (fail func-name "vreg ~a has duplicate option ~a"
            (vreg->string (car decl)) head))
    (hash-set! seen head #t)))

;; ---------------------------------------------------------------------------
;; alloc
;; ---------------------------------------------------------------------------

(define (parse-alloc func-name form vregs)
  (unless (tagged? form 'alloc)
    (fail func-name "malformed alloc form: ~e" form))
  (define pins (make-hash))
  (for ([entry (in-list (cdr form))])
    (cond
      [(reserve-entry? entry) (void)]

      [(pin-entry? entry)
       (define vreg (cadr entry))
       (define native (caddr entry))
       (unless (hash-has-key? vregs vreg)
         (fail func-name "pin refers to undeclared vreg ~a" (vreg->string vreg)))
       (when (vreg-decl-address-taken? (hash-ref vregs vreg))
         (fail func-name "address-taken vreg ~a cannot be pinned" (vreg->string vreg)))
       (define previous (hash-ref pins vreg #f))
       (when (and previous (not (equal? previous native)))
         (fail func-name "vreg ~a is pinned to two registers (~e and ~e)"
               (vreg->string vreg) previous native))
       (hash-set! pins vreg native)]

      [(clobber-entry? entry) (void)]

      [else
       (fail func-name "invalid alloc entry: ~e" entry)]))
  pins)

;; ---------------------------------------------------------------------------
;; blocks / entry
;; ---------------------------------------------------------------------------

(define (parse-entry func-name form)
  (unless (entry-form? form)
    (fail func-name "malformed entry form: ~e" form))
  (cadr form))

(define (parse-blocks func-name forms)
  (define table (make-hash))
  (for ([form (in-list forms)])
    (unless (block-form? form)
      (fail func-name "malformed block: ~e" form))
    (define name (cadr form))
    (when (hash-has-key? table name)
      (fail func-name "block ~a is declared twice" name))
    (hash-set! table name form))
  table)

(define (verify-block func-name block-form vregs blocks)
  (define block-name (cadr block-form))
  (define forms (cddr block-form))

  (define terms (filter (lambda (x) (and (form? x) (eq? (car x) 'term))) forms))
  (cond
    [(null? terms)
     (fail func-name "block ~a has no term" block-name)]
    [(> (length terms) 1)
     (fail func-name "block ~a has more than one term" block-name)]
    [else
     (define term (car terms))
     (unless (equal? term (last forms))
       (fail func-name "block ~a: term must be the last form" block-name))
     (unless (term-form? term)
       (fail func-name "block ~a: malformed term: ~e" block-name term))
     (for ([op (in-list (drop-right forms 1))])
       (verify-op func-name block-name op vregs))
     (verify-term func-name block-name term vregs blocks)]))

;; ---------------------------------------------------------------------------
;; term
;; ---------------------------------------------------------------------------

(define (verify-term func-name block-name term vregs blocks)
  (define expr (cadr term))
  (match expr
    [(list 'jump (? symbol? target))
     (check-block-target func-name block-name target blocks)]

    [(list 'branch (? condition-form? cond) (? symbol? then) (? symbol? else))
     (verify-condition func-name block-name cond vregs)
     (check-block-target func-name block-name then blocks)
     (check-block-target func-name block-name else blocks)]

    [(list 'return operands ...)
     (for ([operand (in-list operands)])
       (check-operand func-name block-name "return" operand vregs))]

    [(list 'trap) (void)]

    [_ (fail func-name "block ~a: malformed term: ~e" block-name term)]))

(define (verify-condition func-name block-name cond vregs)
  (match cond
    [(list _ a b)
     (check-condition-operand func-name block-name a vregs)
     (check-condition-operand func-name block-name b vregs)]
    [_ (fail func-name "block ~a: malformed condition: ~e" block-name cond)]))

(define (check-condition-operand func-name block-name operand vregs)
  (cond
    [(exact-integer? operand) (void)]
    [(vreg? operand)
     (unless (hash-has-key? vregs operand)
       (fail func-name "block ~a: condition uses undeclared vreg ~a"
             block-name (vreg->string operand)))]
    [else
     (fail func-name "block ~a: condition operand must be integer or vreg, got: ~e"
           block-name operand)]))

(define (check-block-target func-name block-name target blocks)
  (unless (hash-has-key? blocks target)
    (fail func-name "block ~a jumps to undeclared block ~a"
          block-name target)))

;; ---------------------------------------------------------------------------
;; ops
;; ---------------------------------------------------------------------------

(define (verify-op func-name block-name op vregs)
  (unless (form? op)
    (fail func-name "block ~a: op must be a proper non-empty list: ~e"
          block-name op))
  (define head (car op))
  (cond
    [(eq? head 'asm)
     (verify-asm func-name block-name op vregs)]

    [(forbidden-virtual-head? head)
     (fail func-name "block ~a: ~a is not allowed in virtual IR"
           block-name head)]

    [(not (virtual-op-head? head))
     (fail func-name "block ~a: unknown virtual op ~a" block-name head)]

    [else
     (case head
       [(const) (verify-const func-name block-name op vregs)]
       [(copy) (verify-copy func-name block-name op vregs)]
       [(load) (verify-load func-name block-name op vregs)]
       [(store) (verify-store func-name block-name op vregs)]
       [(addr) (verify-addr func-name block-name op vregs)]
       [(call) (verify-call func-name block-name op vregs)]
       [else
        (if (binary-op-head? head)
            (verify-binary func-name block-name op vregs)
            (fail func-name "block ~a: unhandled virtual op ~a" block-name head))])]))

(define (verify-const func-name block-name op vregs)
  (expect-length func-name block-name op 3)
  (check-vreg func-name block-name "const destination" (cadr op) vregs)
  (unless (exact-integer? (caddr op))
    (fail func-name "block ~a: const immediate must be an integer: ~e"
          block-name (caddr op))))

(define (verify-copy func-name block-name op vregs)
  (expect-length func-name block-name op 3)
  (check-vreg func-name block-name "copy destination" (cadr op) vregs)
  (check-operand func-name block-name "copy source" (caddr op) vregs))

(define (verify-binary func-name block-name op vregs)
  (expect-length func-name block-name op 4)
  (check-vreg func-name block-name "binary destination" (cadr op) vregs)
  (check-operand func-name block-name "binary operand" (caddr op) vregs)
  (check-operand func-name block-name "binary operand" (cadddr op) vregs))

(define (verify-load func-name block-name op vregs)
  (expect-length func-name block-name op 5)
  (check-vreg func-name block-name "load destination" (cadr op) vregs)
  (check-operand func-name block-name "load base" (caddr op) vregs)
  (unless (exact-integer? (cadddr op))
    (fail func-name "block ~a: load offset must be an integer: ~e"
          block-name (cadddr op)))
  (check-type func-name block-name "load" (car (cddddr op))))

(define (verify-store func-name block-name op vregs)
  (expect-length func-name block-name op 5)
  (check-operand func-name block-name "store base" (cadr op) vregs)
  (unless (exact-integer? (caddr op))
    (fail func-name "block ~a: store offset must be an integer: ~e"
          block-name (caddr op)))
  (check-operand func-name block-name "store source" (cadddr op) vregs)
  (check-type func-name block-name "store" (car (cddddr op))))

(define (verify-addr func-name block-name op vregs)
  (expect-length func-name block-name op 3)
  (define dst (cadr op))
  (define src (caddr op))
  (check-vreg func-name block-name "addr destination" dst vregs)
  (cond
    [(global-ref? src) (void)]
    [(vreg? src)
     (unless (hash-has-key? vregs src)
       (fail func-name "block ~a: addr source uses undeclared vreg ~a"
             block-name (vreg->string src)))
     (unless (vreg-decl-address-taken? (hash-ref vregs src))
       (fail func-name "block ~a: addr source ~a is not (address-taken)"
             block-name (vreg->string src)))]
    [else
     (fail func-name "block ~a: addr source must be (global ...) or an address-taken vreg: ~e"
           block-name src)]))

(define (verify-call func-name block-name op vregs)
  (when (< (length op) 3)
    (fail func-name "block ~a: call needs a destination and a global target: ~e"
          block-name op))
  (check-vreg func-name block-name "call destination" (cadr op) vregs)
  (unless (global-ref? (caddr op))
    (fail func-name "block ~a: call target must be (global chain): ~e"
          block-name (caddr op)))
  (for ([arg (in-list (cdddr op))])
    (check-operand func-name block-name "call argument" arg vregs)))

(define (expect-length func-name block-name op n)
  (unless (= (length op) n)
    (fail func-name "block ~a: ~a expects ~a operands, got: ~e"
          block-name (car op) (sub1 n) op)))

(define (check-vreg func-name block-name who x vregs)
  (unless (vreg? x)
    (fail func-name "block ~a: ~a must be a vreg, got: ~e"
          block-name who x))
  (unless (hash-has-key? vregs x)
    (fail func-name "block ~a: ~a uses undeclared vreg ~a"
          block-name who (vreg->string x))))

(define (check-operand func-name block-name who x vregs)
  (cond
    [(exact-integer? x) (void)]
    [(vreg? x)
     (unless (hash-has-key? vregs x)
       (fail func-name "block ~a: ~a uses undeclared vreg ~a"
             block-name who (vreg->string x)))]
    [(global-ref? x) (void)]
    [else
     (fail func-name "block ~a: ~a must be integer, vreg, or (global chain), got: ~e"
           block-name who x)]))

(define (check-type func-name block-name who x)
  (unless (type-form? x)
    (fail func-name "block ~a: ~a has invalid type: ~e"
          block-name who x)))

;; ---------------------------------------------------------------------------
;; asm
;; ---------------------------------------------------------------------------

(define (verify-asm func-name block-name op vregs)
  (define clauses (cdr op))
  (define table (make-hash))
  (for ([clause (in-list clauses)])
    (unless (asm-clause? clause)
      (fail func-name "block ~a: malformed asm clause: ~e" block-name clause))
    (define head (car clause))
    (when (hash-has-key? table head)
      (fail func-name "block ~a: asm has duplicate ~a clause" block-name head))
    (hash-set! table head clause))

  (for ([head (in-list '(inputs outputs clobber code))])
    (unless (hash-has-key? table head)
      (fail func-name "block ~a: asm is missing ~a clause" block-name head)))

  (verify-asm-bindings func-name block-name 'inputs (hash-ref table 'inputs) vregs)
  (verify-asm-bindings func-name block-name 'outputs (hash-ref table 'outputs) vregs)
  (verify-asm-clobber func-name block-name (hash-ref table 'clobber))
  (verify-asm-code func-name block-name (hash-ref table 'code)))

(define (verify-asm-bindings func-name block-name who clause vregs)
  (define seen (make-hash))
  (for ([entry (in-list (cdr clause))])
    (unless (asm-binding-entry? entry)
      (fail func-name "block ~a: asm ~a entry must be ((vreg) (native xN)): ~e"
            block-name who entry))
    (define vreg (car entry))
    (define native (cadr entry))
    (unless (hash-has-key? vregs vreg)
      (fail func-name "block ~a: asm ~a uses undeclared vreg ~a"
            block-name who (vreg->string vreg)))
    (define previous (hash-ref seen vreg #f))
    (when (and previous (not (equal? previous native)))
      (fail func-name "block ~a: asm ~a binds ~a to two registers (~e and ~e)"
            block-name who (vreg->string vreg) previous native))
    (hash-set! seen vreg native)))

(define (verify-asm-clobber func-name block-name clause)
  (for ([entry (in-list (cdr clause))])
    (unless (asm-clobber-entry? entry)
      (fail func-name "block ~a: asm clobber entry must be (native xN): ~e"
            block-name entry))))

(define (verify-asm-code func-name block-name clause)
  (for ([item (in-list (cdr clause))])
    (verify-asm-code-tree func-name block-name item)))

;; asm.code 是封闭 machine 块：允许 native / label / 局部 symbol，
;; 不允许 vreg、global、term，也不允许别的核心层形状。
(define (verify-asm-code-tree func-name block-name x)
  (cond
    [(and (form? x) (memq (car x) '($ global term allocation slot frame frame-slot scratch)))
     (fail func-name "block ~a: asm.code may not contain ~a: ~e"
           block-name (car x) x)]

    [(and (form? x) (eq? (car x) 'label))
     (unless (and (pair? (cdr x)) (andmap symbol? (cdr x)))
       (fail func-name "block ~a: asm.code label must take one or more symbols: ~e"
             block-name x))]

    [(and (form? x) (eq? (car x) 'native))
     (unless (physical-register? x)
       (fail func-name "block ~a: asm.code native register must be x0..x31: ~e"
             block-name x))]

    [(list? x)
     (for ([sub (in-list x)])
       (verify-asm-code-tree func-name block-name sub))]

    [else (void)]))

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (vreg->string vreg)
  (format "($ ~a)" (cadr vreg)))

(define (fail func-name fmt . args)
  (apply error
         'verify-virtual
         (string-append "func ~a: " fmt)
         (chain->string func-name)
         args))
