#lang racket
;;; ir/verify-machine.rkt
;;;
;;; machine IR 的验证。它只检查 materialize 之后不能再出现的东西：
;;;   - 没有 ($ x)；
;;;   - 没有裸 (slot n) 值操作数；
;;;   - 值操作数是 (native xN)、整数、(global chain)；
;;;   - 内存地址可以用 (frame-slot n)；
;;;   - frame / scratch 形状合法；
;;;   - block / term 形状仍然合法；
;;;   - j / b / label 还没有进入机器函数（它们是 layout 之后的形状）。
;;;
;;; 它不检查：
;;;   - 寄存器分配是否最优；
;;;   - 指令选择是否正确；
;;;   - 布局、island、编码；
;;;   - raw（raw 是独立的 machine 单元）。

(require racket/list
         "../core/sexp.rkt"
         "shape.rkt"
         "frame.rkt"
         "scratch.rkt"
         "../asm/code.rkt")

(provide verify-machine
         verify-machine-program
         verify-machine-func)

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (verify-machine-program program)
  (unless (list? program)
    (error 'verify-machine "program must be a proper list: ~e" program))
  (for ([item (in-list program)])
    (unless (and (tagged? item 'func))
      (error 'verify-machine "machine program top level only accepts func: ~e" item))
    (verify-func item))
  program)

(define verify-machine verify-machine-program)

(define (verify-machine-func func)
  (verify-func func)
  func)

;; ---------------------------------------------------------------------------
;; 函数
;; ---------------------------------------------------------------------------

(define (verify-func func)
  (unless (and (tagged? func 'func)
               (>= (length func) 2)
               (chain? (cadr func)))
    (error 'verify-machine "malformed func: ~e" func))
  (define func-name (cadr func))
  (define body (cddr func))

  (define frame #f)
  (define scratch #f)
  (define entry #f)
  (define block-forms '())

  (for ([item (in-list body)])
    (cond
      [(tagged? item 'frame)
       (when frame
         (fail func-name "more than one frame form"))
       (unless (frame-form? item)
         (fail func-name "malformed frame: ~e" item))
       (set! frame item)]

      [(tagged? item 'scratch)
       (when scratch
         (fail func-name "more than one scratch form"))
       (unless (scratch-form? item)
         (fail func-name "malformed scratch: ~e" item))
       (check-scratch-unique! (cdr item) 'verify-machine)
       (set! scratch item)]

      [(tagged? item 'entry)
       (when entry
         (fail func-name "more than one entry form"))
       (unless (entry-form? item)
         (fail func-name "malformed entry: ~e" item))
       (set! entry item)]

      [(tagged? item 'block)
       (set! block-forms (cons item block-forms))]

      [(and (form? item) (memq (car item) '(vregs alloc allocation)))
       (fail func-name "virtual allocation form ~a is not allowed in machine IR"
             (car item))]

      [else
       (fail func-name "unexpected form in machine func body: ~e" item)]))

  (unless entry
    (fail func-name "missing (entry ...) form"))

  (define ordered-blocks (reverse block-forms))
  (define blocks (parse-blocks func-name ordered-blocks))
  (when (zero? (hash-count blocks))
    (fail func-name "function has no blocks"))

  (define entry-name (cadr entry))
  (unless (hash-has-key? blocks entry-name)
    (fail func-name "entry block ~a is not declared" entry-name))

  (for ([block-form (in-list ordered-blocks)])
    (verify-block func-name block-form blocks))

  ;; frame 存在时，所有 (frame-slot n) 必须能在 frame 里找到。
  (when frame
    (define used-slots
      (append* (for/list ([block (in-list ordered-blocks)])
                 (collect-frame-slots (cddr block)))))
    (for ([slot (in-list (remove-duplicates used-slots))])
      (unless (frame-slot-offset frame slot)
        (fail func-name "frame-slot ~a has no entry in the frame" slot))))

  (void))

(define (parse-blocks func-name forms)
  (define table (make-hash))
  (for ([form (in-list forms)])
    (define name (cadr form))
    (when (hash-has-key? table name)
      (fail func-name "block ~a is declared twice" name))
    (hash-set! table name form))
  table)

(define (verify-block func-name block-form blocks)
  (define block-name (cadr block-form))
  (define forms (cddr block-form))

  (define terms
    (filter (lambda (x) (and (form? x) (eq? (car x) 'term))) forms))
  (cond
    [(null? terms)
     (fail func-name "block ~a has no term" block-name)]
    [(> (length terms) 1)
     (fail func-name "block ~a has more than one term" block-name)]
    [else
     (define term (car terms))
     (unless (equal? term (last forms))
       (fail func-name "block ~a: term must be the last form" block-name))
     (for ([op (in-list (drop-right forms 1))])
       (verify-op func-name block-name op))
     (verify-term func-name block-name term blocks)]))

;; ---------------------------------------------------------------------------
;; term
;; ---------------------------------------------------------------------------

(define (verify-term func-name block-name term blocks)
  (define expr (cadr term))
  (match expr
    [(list 'jump (? symbol? target))
     (check-block-target func-name block-name target blocks)]

    [(list 'branch (list (? condition-head? h) a b) (? symbol? then) (? symbol? else))
     (verify-condition-operand func-name block-name h a)
     (verify-condition-operand func-name block-name h b)
     (check-block-target func-name block-name then blocks)
     (check-block-target func-name block-name else blocks)]

    [(list 'return operands ...)
     (for ([operand (in-list operands)])
       (verify-machine-tree func-name block-name "return operand" operand))]

    [(list 'trap) (void)]

    [_ (fail func-name "block ~a: malformed machine term: ~e" block-name term)]))

(define (verify-condition-operand func-name block-name _head operand)
  (cond
    [(exact-integer? operand) (void)]
    [(physical-register? operand) (void)]
    [else
     (fail func-name
           "block ~a: condition operand must be integer or (native xN), got: ~e"
           block-name operand)]))

(define (check-block-target func-name block-name target blocks)
  (unless (hash-has-key? blocks target)
    (fail func-name "block ~a jumps to undeclared block ~a"
          block-name target)))

;; ---------------------------------------------------------------------------
;; ops
;; ---------------------------------------------------------------------------

;; 这些 head 属于 virtual IR、layout 或结构层，不能出现在机器函数的 op 里。
;; asm.code / raw 是封闭 machine 块，单独检查。
(define forbidden-machine-op-heads
  '(label j jal jalr ret
    beq bne blt bge bltu bgeu beqz bnez ble bgt
    c.j c.jal c.beqz c.bnez
    term jump branch return trap
    block entry frame scratch func vregs alloc allocation
    module provide require data raw
    global native frame-slot slot))

(define (verify-op func-name block-name op)
  (unless (and (form? op) (symbol? (car op)))
    (fail func-name "block ~a: machine op must be a non-empty proper list: ~e"
          block-name op))
  (define head (car op))
  (cond
    [(eq? head 'asm)
     (verify-machine-asm func-name block-name op)]

    [(eq? head 'asm-code)
     (with-handlers ([exn:fail?
                      (lambda (e)
                        (fail func-name "block ~a: malformed asm-code: ~a"
                              block-name (exn-message e)))])
       (normalize-asm-code (cdr op)))]

    [(eq? head 'call-target)
     (unless (and (= 2 (length op)) (global-ref? (cadr op)))
       (fail func-name "block ~a: malformed call-target: ~e" block-name op))]

    [(eq? head 'call)
     (verify-machine-call func-name block-name op)]

    [(memq head forbidden-machine-op-heads)
     (fail func-name "block ~a: ~a is not a machine op before layout (except asm.code / raw)"
           block-name head)]

    [else
     (for ([operand (in-list (cdr op))])
       (verify-machine-tree func-name block-name head operand))]))

(define (verify-machine-call func-name block-name op)
  (when (< (length op) 3)
    (fail func-name "block ~a: malformed call: ~e" block-name op))
  (verify-machine-tree func-name block-name "call destination" (cadr op))
  (unless (global-ref? (caddr op))
    (fail func-name "block ~a: call target must be (global chain): ~e"
          block-name (caddr op)))
  (for ([arg (in-list (cdddr op))])
    (verify-machine-tree func-name block-name "call argument" arg)))

;; ---------------------------------------------------------------------------
;; machine operand tree
;; ---------------------------------------------------------------------------

(define (verify-machine-tree func-name block-name who x)
  (cond
    [(exact-integer? x) (void)]

    [(physical-register? x) (void)]

    [(global-ref? x) (void)]

    [(vreg? x)
     (fail func-name "block ~a: ~a still contains vreg ~a"
           block-name who (vreg->string x))]

    [(and (form? x) (eq? (car x) 'native))
     (fail func-name "block ~a: ~a has malformed native register: ~e"
           block-name who x)]

    [(and (form? x) (eq? (car x) 'global))
     (fail func-name "block ~a: ~a has malformed global reference: ~e"
           block-name who x)]

    [(and (form? x) (eq? (car x) 'frame-slot))
     (unless (and (= 2 (length x))
                  (exact-nonnegative-integer? (cadr x)))
       (fail func-name "block ~a: ~a has malformed frame-slot: ~e"
             block-name who x))]

    [(and (form? x) (eq? (car x) 'slot))
     (fail func-name "block ~a: bare (slot n) is not a machine operand: ~e"
           block-name x)]

    [(form? x)
     (unless (symbol? (car x))
       (fail func-name "block ~a: malformed operand form: ~e" block-name x))
     (when (memq (car x) '(term block entry frame scratch func vregs alloc
                          allocation module provide require data raw))
       (fail func-name "block ~a: structural form ~a is not a machine operand"
             block-name (car x)))
     (for ([sub (in-list (cdr x))])
       (verify-machine-tree func-name block-name who sub))]

    [(symbol? x)
     (fail func-name "block ~a: bare symbol ~a is not a machine operand"
           block-name x)]

    [else
     (fail func-name "block ~a: unsupported machine operand: ~e" block-name x)]))

;; ---------------------------------------------------------------------------
;; asm
;; ---------------------------------------------------------------------------

;; materialize 之后 asm 的 vreg 边界已经变成物理寄存器。
;; 这里只接受 machine 形式的 bindings；局部 label / 分支留在 code 里。
(define (verify-machine-asm func-name block-name op)
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

  (verify-machine-asm-bindings func-name block-name 'inputs
                                (hash-ref table 'inputs))
  (verify-machine-asm-bindings func-name block-name 'outputs
                                (hash-ref table 'outputs))
  (for ([entry (in-list (cdr (hash-ref table 'clobber)))])
    (unless (physical-register? entry)
      (fail func-name "block ~a: asm clobber entry must be (native xN): ~e"
            block-name entry)))
  (for ([item (in-list (cdr (hash-ref table 'code)))])
    (verify-asm-code-tree func-name block-name item)))

(define (verify-machine-asm-bindings func-name block-name who clause)
  (for ([entry (in-list (cdr clause))])
    (match entry
      [(list (? physical-register?) (? physical-register?)) (void)]
      [(list (? vreg? _) _)
       (fail func-name "block ~a: asm ~a still contains a vreg: ~e"
             block-name who entry)]
      [_ (fail func-name "block ~a: asm ~a entry must be ((native xN) (native xM)): ~e"
               block-name who entry)])))

;; asm.code 是封闭 machine 块：允许局部 label / j / b / 符号，
;; 但不允许 vreg、global、term 或别的核心层形状。
(define (verify-asm-code-tree func-name block-name x)
  (cond
    [(and (form? x)
          (memq (car x) '($ global term allocation slot frame frame-slot scratch
                         vregs alloc block entry func module provide require data raw)))
     (fail func-name "block ~a: asm.code may not contain ~a: ~e"
           block-name (car x) x)]

    [(and (form? x) (eq? (car x) 'native))
     (unless (physical-register? x)
       (fail func-name "block ~a: asm.code native register must be x0..x31: ~e"
             block-name x))]

    [(form? x)
     (for ([sub (in-list (cdr x))])
       (verify-asm-code-tree func-name block-name sub))]

    [else (void)]))

;; ---------------------------------------------------------------------------
;; frame-slot 收集
;; ---------------------------------------------------------------------------

(define (collect-frame-slots x)
  (cond
    [(and (form? x) (eq? (car x) 'frame-slot))
     (list (cadr x))]
    [(and (form? x) (memq (car x) '(frame scratch)))
     '()]
    [(list? x)
     (append* (for/list ([sub (in-list x)])
                (collect-frame-slots sub)))]
    [else '()]))

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (vreg->string vreg)
  (format "($ ~a)" (cadr vreg)))

(define (fail func-name fmt . args)
  (apply error
         'verify-machine
         (string-append "func ~a: " fmt)
         (chain->string func-name)
         args))
