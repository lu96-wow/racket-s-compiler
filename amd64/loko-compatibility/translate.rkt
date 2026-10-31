#lang racket
;;; amd64/loko-compatibility/translate.rkt
;;;
;;; Loko 的 amd64 汇编写法 -> 本后端的核心 item。
;;;
;;; 本层只做“写法兼容”，不做布局、地址、编码：
;;;
;;;   mem64+ / mem+ / mem128+       -> b64 / bN / b128 命名字段
;;;   %label                         -> label
;;;   %comment                       -> comment
;;;   %align                         -> align（不处理显式非零填充字节）
;;;   %u8/%u16/%u32/%u64/%u128       -> value
;;;   %vu8                           -> bytes
;;;   %utf8z                         -> bytes ... 0
;;;   %equiv                         -> alias，引用处内联
;;;   sal/movsxd/setcc/cmovcc        -> 规范拼写
;;;   call/jmp + 内存操作数           -> call-indirect / jmp-indirect
;;;
;;; 输入是一个显式的来源：
;;;
;;;   (loko-source (text item ...) (data item ...))
;;;
;;; 输出还是一个 s-expression：
;;;
;;;   (loko-compat
;;;     (program-items item ...)
;;;     (data-items item ...)
;;;     (aliases (alias 名字 值) ...)
;;;     (problems problem ...))
;;;
;;; 不支持的写法不会偷偷丢掉：它变成 (problem 种类 细节 ...) 并出现在
;;; problems 里。流层（flow/flow.rkt）把非空 problems 当错误。
;;;
;;; 这里是**纯变换**：输入、输出都是 s-expression；内部 hash 只是本次
;;; 变换的局部索引（标签/别名），没有跨调用状态，也不改输入。

(require racket/match
         "../amd64-asm/sexp.rkt"
         "../amd64-asm/registers.rkt"
         "../compiler/item.rkt")

(provide translate-loko-source
         translate-loko-text-only
         translate-loko-data-only
         loko-source?
         loko-memory?
         loko-memory-width
         loko-directive?
         loko-compat-fields)

;; ---------------------------------------------------------------------------
;; 局部上下文
;; ---------------------------------------------------------------------------

;; labels:      标签对象 -> 路径
;; raw-aliases: %equiv 的原始值
;; aliases:     已解析的 %equiv 值
;; problems:    本次变换发现的问题（逆序）
;; counter:     匿名标签编号
(struct ctx (labels raw-aliases aliases problems counter) #:mutable)

;; Internal problems are records so they cannot collide with a label path
;; whose name happens to be `problem`.  They become tagged lists only at the
;; layer boundary.
(struct loko-problem (kind detail) #:transparent)

(define (problem kind . detail)
  (loko-problem kind detail))

(define (problem? x)
  (loko-problem? x))

(define (problem->sexp p)
  (cons 'problem (cons (loko-problem-kind p) (loko-problem-detail p))))

(define (record-problem! ctx p)
  (set-ctx-problems! ctx (cons p (ctx-problems ctx))))

(define (record-problem-comment! ctx p)
  (record-problem! ctx p)
  (list (problem->comment-form p)))

(define (problem->comment-form p)
  (list 'comment (cons 'loko-compat-problem (cdr (problem->sexp p)))))

;; ---------------------------------------------------------------------------
;; 来源
;; ---------------------------------------------------------------------------

(define (loko-source-parts src)
  (define fields
    (cond
      [(and (form? src) (eq? (car src) 'loko-source)) (cdr src)]
      [(and (list? src) (andmap pair? src)) src]
      [else
       (error 'translate-loko-source
              "expected (loko-source (text ...) (data ...)): ~e" src)]))
  (define text (assq 'text fields))
  (define data (assq 'data fields))
  (unless (and text data)
    (error 'translate-loko-source
           "expected (loko-source (text ...) (data ...)): ~e" src))
  (unless (and (list? (cdr text)) (list? (cdr data)))
    (error 'translate-loko-source "text/data must be item lists: ~e" src))
  (values (cdr text) (cdr data)))

(define (loko-source? src)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (loko-source-parts src)
    #t))

(define (translate-loko-text-only text)
  (translate-loko-source (list 'loko-source (cons 'text text) (cons 'data '()))))

(define (translate-loko-data-only data)
  (translate-loko-source (list 'loko-source (cons 'text '()) (cons 'data data))))

(define (loko-compat-fields out)
  (and (form? out)
       (eq? (car out) 'loko-compat)
       (cdr out)))

;; ---------------------------------------------------------------------------
;; %equiv 别名
;; ---------------------------------------------------------------------------

(define (collect-equiv! ctx item)
  (when (and (form? item) (eq? (car item) '%equiv))
    (match (cdr item)
      [(list name expr) (hash-set! (ctx-raw-aliases ctx) name expr)]
      [_ (record-problem! ctx (problem 'bad-equiv item))])))

(define (resolve-alias ctx name resolving)
  (cond
    [(hash-has-key? (ctx-aliases ctx) name)
     (hash-ref (ctx-aliases ctx) name)]
    [(member name resolving)
     (problem 'alias-cycle name)]
    [else
     (define raw (hash-ref (ctx-raw-aliases ctx) name #f))
     (cond
       [(not raw) (problem 'unknown-alias name)]
       [else
        (define v (translate-expr ctx raw (cons name resolving)))
        (unless (problem? v)
          (hash-set! (ctx-aliases ctx) name v))
        v])]))

;; ---------------------------------------------------------------------------
;; 标签
;; ---------------------------------------------------------------------------

;; 可读标签（symbol/string/number）保留原名；其它对象（Loko codegen 用
;; #(const x) / #(foo n) 这类 vector）映射到一个稳定的匿名名字。
(define (label-path ctx obj)
  (cond
    [(or (symbol? obj) (string? obj) (number? obj)) (list obj)]
    [else
     (cond
       [(hash-ref (ctx-labels ctx) obj #f)]
       [else
        (define n (ctx-counter ctx))
        (define sym (string->symbol (format "loko-label-~a" n)))
        (define path (list sym))
        (set-ctx-counter! ctx (add1 n))
        (hash-set! (ctx-labels ctx) obj path)
        path])]))

;; ---------------------------------------------------------------------------
;; 内存操作数
;; ---------------------------------------------------------------------------

(define (loko-memory? x)
  (and (form? x)
       (symbol? (car x))
       (let ([s (symbol->string (car x))])
         (or (string=? s "mem+")
             (regexp-match? #rx"^mem[0-9]+\\+$" s)))))

(define (loko-memory-width x)
  (define s (symbol->string (car x)))
  (cond
    [(string=? s "mem+") #f]
    [(regexp-match #rx"^mem([0-9]+)\\+$" s)
     => (lambda (m) (string->number (cadr m)))]
    [else #f]))

(struct mem-parts (base index scale seg disp) #:transparent)
(struct scaled (index scale) #:transparent)

(define (register-symbol? x)
  (and (symbol? x) (register-name? x)))

(define (register-width-of x)
  (and (register-symbol? x)
       (reg-width (lookup-register x))))

(define (parse-scale term)
  (define factors (cdr term))
  (define regs (filter register-symbol? factors))
  (cond
    [(> (length regs) 1)
     (problem 'multiple-index-registers term)]
    [(= 1 (length regs))
     (define index (car regs))
     (define bad
       (for/first ([f (in-list factors)]
                   #:unless (or (eq? f index)
                                (eq? f 'wordsize)
                                (exact-integer? f)))
         f))
     (cond
       [bad (problem 'bad-scale-factor term bad)]
       [else
        (define scale
          (for/fold ([s 1]) ([f (in-list factors)] #:unless (eq? f index))
            (cond
              [(eq? f 'wordsize) (* s 8)]
              [(exact-integer? f) (* s f)])))
        (if (memq scale '(1 2 4 8))
            (scaled index scale)
            (problem 'bad-scale term scale))])]
    [else
     ;; No register: this is a constant expression, handled as displacement.
     (translate-expr ctx term)]))

(define (combine-disp terms)
  (define ints (filter exact-integer? terms))
  (define others (filter (lambda (x) (not (exact-integer? x))) terms))
  (define sum (apply + ints))
  (cond
    [(null? others) sum]
    [(null? (cdr others)) (if (zero? sum) (car others) (list '+ sum (car others)))]
    [else (cons '+ (cons sum others))]))

(define (parse-mem-parts ctx terms)
  (let loop ([terms terms] [base #f] [index #f] [scale 1] [seg #f] [disp '()])
    (cond
      [(null? terms)
       (cond
         [(and (eq? base 'rip) index)
          (problem 'rip-with-index (cons 'mem+ terms))]
         [(and index (memq index '(rsp r12)))
          (problem 'bad-index-register index)]
         [(and base index
               (not (eq? base 'rip))
               (not (= (register-width-of base) (register-width-of index))))
          (problem 'base-index-width-mismatch base index)]
         [else
          (mem-parts base index scale seg
                     (combine-disp (reverse disp)))])]
      [else
       (define t (car terms))
       (cond
         [(memq t '(fs gs))
          (if seg
              (problem 'multiple-segments t)
              (loop (cdr terms) base index scale t disp))]

         [(eq? t 'rip)
          (if base
              (problem 'multiple-base-registers t)
              (loop (cdr terms) 'rip index scale seg disp))]

         [(register-symbol? t)
          (cond
            [(not base) (loop (cdr terms) t index scale seg disp)]
            [(not index) (loop (cdr terms) base t scale seg disp)]
            [else (problem 'multiple-registers t)])]

         [(and (form? t) (eq? (car t) '*))
          (define s (parse-scale t))
          (cond
            [(problem? s) s]
            [(scaled? s)
             (if index
                 (problem 'multiple-index-registers t)
                 (loop (cdr terms) base (scaled-index s)
                       (scaled-scale s) seg disp))]
            [else
             ;; constant expression
             (loop (cdr terms) base index scale seg (cons s disp))])]

         [else
          (define e (translate-expr ctx t))
          (if (problem? e)
              e
              (loop (cdr terms) base index scale seg (cons e disp)))])])))

(define (width->mem-head w)
  (case w
    [(8) 'b8]
    [(16) 'b16]
    [(32) 'b32]
    [(64) 'b64]
    [(128) 'b128]
    [else #f]))

(define (translate-mem ctx mem default-width)
  (define explicit (loko-memory-width mem))
  (define parts (parse-mem-parts ctx (cdr mem)))
  (cond
    [(problem? parts) parts]
    [else
     (define base (mem-parts-base parts))
     (define index (mem-parts-index parts))
     (define width
       (cond
         [explicit explicit]
         [(eq? default-width 'ambiguous) #f]
         [default-width default-width]
         [else
          (or (register-width-of base)
              (register-width-of index)
              (and (eq? base 'rip) 64)
              #f)]))
     (cond
       [(not width)
        (problem 'ambiguous-memory-width mem)]
       [(not (width->mem-head width))
        (problem 'unsupported-memory-width mem width)]
       [else
        (define disp (mem-parts-disp parts))
        (define fields
          (append
           (if base (list (list 'base base)) '())
           (if index (list (list 'index index) (list 'scale (mem-parts-scale parts))) '())
           (list (list 'disp disp))
           (if (mem-parts-seg parts) (list (list 'seg (mem-parts-seg parts))) '())))
        (cons (width->mem-head width) fields)])]))

;; ---------------------------------------------------------------------------
;; 表达式
;; ---------------------------------------------------------------------------

(define (translate-sum ctx args resolving)
  (define vals (for/list ([a (in-list args)]) (translate-expr ctx a resolving)))
  (cond
    [(ormap problem? vals) (for/first ([v (in-list vals)] #:when (problem? v)) v)]
    [(null? vals) 0]
    [(andmap exact-integer? vals) (apply + vals)]
    [(null? (cdr vals)) (car vals)]
    [else (cons '+ vals)]))

(define (translate-diff ctx args resolving)
  (define vals (for/list ([a (in-list args)]) (translate-expr ctx a resolving)))
  (cond
    [(ormap problem? vals) (for/first ([v (in-list vals)] #:when (problem? v)) v)]
    [(null? vals) (problem 'empty-difference args)]
    [(null? (cdr vals))
     (define v (car vals))
     (if (exact-integer? v) (- v) (list '- 0 v))]
    [(andmap exact-integer? vals) (apply - vals)]
    [else (cons '- vals)]))

(define (const-op-value op vals)
  (case op
    [(* ) (apply * vals)]
    [(<< asl) (apply arithmetic-shift vals)]
    [(>> asr) (apply arithmetic-shift (list (car vals) (- (cadr vals))))]
    [(ash) (apply arithmetic-shift vals)]
    [(bitwise-and) (apply bitwise-and vals)]
    [(bitwise-ior) (apply bitwise-ior vals)]
    [(bitwise-bit-field) (apply bitwise-bit-field vals)]
    [else #f]))

(define (translate-const-op ctx expr resolving)
  (define vals (for/list ([a (in-list (cdr expr))])
                 (translate-expr ctx a resolving)))
  (cond
    [(ormap problem? vals) (for/first ([v (in-list vals)] #:when (problem? v)) v)]
    [(andmap exact-integer? vals)
     (with-handlers ([exn:fail?
                      (lambda (_) (problem 'bad-constant-expression expr))])
       (const-op-value (car expr) vals))]
    [else
     ;; Symbolic bit operations are not part of the core address-expression
     ;; language.  Keep this explicit instead of guessing.
     (problem 'symbolic-bit-expression expr)]))

(define (translate-expr ctx expr [resolving '()])
  (cond
    [(hash-has-key? (ctx-raw-aliases ctx) expr)
     (resolve-alias ctx expr resolving)]
    [(exact-integer? expr) expr]
    [(eq? expr 'wordsize) 8]
    [(symbol? expr)
     (cond
       [(register-name? expr) (problem 'register-in-expression expr)]
       [else (label-path ctx expr)])]
    [(or (string? expr) (vector? expr)) (label-path ctx expr)]
    [(form? expr)
     (case (car expr)
       [($) (problem 'current-ip-expression expr)]
       [(+) (translate-sum ctx (cdr expr) resolving)]
       [(-) (translate-diff ctx (cdr expr) resolving)]
       [(<< >> ash asr asl * bitwise-and bitwise-ior bitwise-bit-field)
        (translate-const-op ctx expr resolving)]
       [else (problem 'unsupported-expression expr)])]
    [else (problem 'bad-expression expr)]))

;; ---------------------------------------------------------------------------
;; 操作数 / item
;; ---------------------------------------------------------------------------

(define (translate-operand ctx op default-width)
  (cond
    [(hash-has-key? (ctx-raw-aliases ctx) op)
     (resolve-alias ctx op '())]
    [(loko-memory? op) (translate-mem ctx op default-width)]
    [(exact-integer? op) op]
    [(symbol? op)
     (cond
       [(register-name? op) op]
       [(memq op '(fs gs rip)) op]
       [else (label-path ctx op)])]
    [(or (string? op) (vector? op)) (label-path ctx op)]
    [(form? op) (translate-expr ctx op)]
    [else op]))

(define (memory-default-width item)
  (define h (car item))
  (define ops (cdr item))
  (cond
    [(memq h '(push pop call jmp)) 64]
    ;; Descriptor-table operands are 10-byte pseudo-descriptors; the encoder
    ;; only needs their address, so any fixed width is fine.
    [(memq h '(lgdt lidt)) 64]
    ;; IN/OUT string forms are 16/32-bit only; Loko writes mem+ and expects
    ;; the 32-bit form in 64-bit mode.
    [(memq h '(ins outs)) 32]
    [(setcc-head? h) 8]
    [(memq h '(movzx movsx)) 'ambiguous]
    [else
     (define regs
       (for/list ([op (in-list ops)]
                  #:when (and (symbol? op) (register-name? op)))
         (reg-width (lookup-register op))))
     (cond
       [(pair? regs) (car regs)]
       [else #f])]))

(define (translate-label ctx item)
  (define args (cdr item))
  (cond
    [(null? args) (record-problem-comment! ctx (problem 'empty-label item))]
    [else
     (list (cons 'label
                 (append* (for/list ([a (in-list args)]) (label-path ctx a)))))])) 

(define (translate-align ctx item)
  (match (cdr item)
    [(list n)
     (if (exact-positive-integer? n)
         (list (list 'align n))
         (record-problem-comment! ctx (problem 'bad-align item)))]
    [(list n byte)
     (cond
       [(not (exact-positive-integer? n))
        (record-problem-comment! ctx (problem 'bad-align item))]
       [(not (eqv? byte 0))
        (record-problem-comment! ctx (problem 'align-fill-not-supported item))]
       [else (list (list 'align n))])]
    [_ (record-problem-comment! ctx (problem 'bad-align item))]))

(define (integer-directive-width h)
  (case h
    [(%u8) 1]
    [(%u16) 2]
    [(%u32) 4]
    [(%u64) 8]
    [(%u128) 16]
    [else #f]))

(define (bytes->item bv)
  (list (cons 'bytes (bytes->list bv))))

(define (translate-u128 ctx expr)
  (if (exact-integer? expr)
      (let* ([low (bitwise-and expr (sub1 (expt 2 64)))]
             [high (arithmetic-shift expr -64)])
        (list (list 'value 8 low) (list 'value 8 high)))
      (record-problem-comment! ctx (problem 'symbolic-u128 expr))))

(define (translate-integer-value ctx width value)
  (cond
    [(bytes? value) (bytes->item value)]
    [else
     (define e (translate-expr ctx value))
     (cond
       [(problem? e) (record-problem-comment! ctx e)]
       [(= width 16) (translate-u128 ctx e)]
       [else (list (list 'value width e))])]))

(define (translate-integer-data ctx item)
  (define width (integer-directive-width (car item)))
  (append* (for/list ([v (in-list (cdr item))])
             (translate-integer-value ctx width v))))

(define (translate-vu8 ctx item)
  (append*
   (for/list ([v (in-list (cdr item))])
     (if (bytes? v)
         (bytes->item v)
         (record-problem-comment! ctx (problem 'bad-vu8 v))))))

(define (translate-utf8z ctx item)
  (append*
   (for/list ([v (in-list (cdr item))])
     (if (string? v)
         (list (cons 'bytes
                     (append (for/list ([b (in-bytes (string->bytes/utf-8 v))]) b)
                             (list 0))))
         (record-problem-comment! ctx (problem 'bad-utf8z v))))))

;; 条件码别名：setcc/cmovcc 的旧拼写都落到同一张表。
(define cc-alias
  (hash
   'o 'o 'no 'no
   'b 'b 'c 'b 'nae 'b
   'ae 'ae 'nb 'ae 'nc 'ae
   'e 'e 'z 'e
   'ne 'ne 'nz 'ne
   'be 'be 'na 'be
   'a 'a 'nbe 'a
   's 's 'ns 'ns
   'p 'p 'pe 'p
   'np 'np 'po 'np
   'l 'l 'nge 'l
   'ge 'ge 'nl 'ge
   'le 'le 'ng 'le
   'g 'g 'nle 'g))

(define (canonical-cc cc)
  (if (symbol? cc) (hash-ref cc-alias cc cc) cc))

(define (head-tail h prefix)
  (define s (symbol->string h))
  (define n (string-length prefix))
  (and (> (string-length s) n)
       (string=? (substring s 0 n) prefix)
       (string->symbol (substring s n))))

(define (setcc-head? h)
  (and (symbol? h) (head-tail h "set") #t))

(define (setcc-head-cc h)
  (define tail (head-tail h "set"))
  (and tail (hash-ref cc-alias tail #f)))

(define (cmovcc-head? h)
  (and (symbol? h) (head-tail h "cmov") #t))

(define (cmovcc-head-cc h)
  (define tail (head-tail h "cmov"))
  (and tail (hash-ref cc-alias tail #f)))

;; Loko writes lock.xadd / rep.movs as one mnemonic.  Turn the prefix into
;; an explicit form so the encoder sees a normal instruction inside.
(define (split-prefixed-head h)
  (cond
    [(head-tail h "lock.") => (lambda (inner) (cons 'lock inner))]
    [(head-tail h "rep.") => (lambda (inner) (cons 'rep inner))]
    [else #f]))

(define (translate-instruction ctx item)
  (define h (car item))
  (define default-width (memory-default-width item))
  (cond
    [(split-prefixed-head h)
     (define p (split-prefixed-head h))
     (define inner-out
       (translate-instruction ctx (cons (cdr p) (cdr item))))
     (cond
       [(and (= 1 (length inner-out))
             (form? (car inner-out))
             (eq? (caar inner-out) 'comment)
             (form? (cadar inner-out))
             (eq? (caadar inner-out) 'loko-compat-problem))
        inner-out]
       [else
        (list (list 'prefix (car p) (car inner-out)))])]

    [(eq? h 'jmpf)
     (record-problem-comment! ctx (problem 'far-jump-not-supported item))]

    [(eq? h 'setcc)
     (match (cdr item)
       [(list cc rm)
        (define op (translate-operand ctx rm 8))
        (if (problem? op)
            (record-problem-comment! ctx op)
            (list (list 'setcc (canonical-cc cc) op)))]
       [_ (record-problem-comment! ctx (problem 'bad-conditional item))])]

    [(eq? h 'cmovcc)
     (match (cdr item)
       [(list cc dst src)
        (define d (translate-operand ctx dst default-width))
        (define s* (translate-operand ctx src default-width))
        (cond
          [(problem? d) (record-problem-comment! ctx d)]
          [(problem? s*) (record-problem-comment! ctx s*)]
          [else (list (list 'cmovcc (canonical-cc cc) d s*))])]
       [_ (record-problem-comment! ctx (problem 'bad-conditional item))])]

    [(memq h '(jcc jcc-short jcc-near))
     (match (cdr item)
       [(list cc target)
        (define t (translate-operand ctx target 64))
        (if (problem? t)
            (record-problem-comment! ctx t)
            (list (list h (canonical-cc cc) t)))]
       [_ (record-problem-comment! ctx (problem 'bad-conditional item))])]

    [(and (setcc-head? h) (setcc-head-cc h))
     (define op (translate-operand ctx (cadr item) 8))
     (if (problem? op)
         (record-problem-comment! ctx op)
         (list (list 'setcc (setcc-head-cc h) op)))]

    [(and (cmovcc-head? h) (cmovcc-head-cc h))
     (define ops
       (for/list ([op (in-list (cdr item))])
         (translate-operand ctx op default-width)))
     (define p (for/first ([op (in-list ops)] #:when (problem? op)) op))
     (if p
         (record-problem-comment! ctx p)
         (list (cons 'cmovcc (cons (cmovcc-head-cc h) ops))))]

    [else
     (define ops
       (for/list ([op (in-list (cdr item))])
         (translate-operand ctx op default-width)))
     (define p (for/first ([op (in-list ops)] #:when (problem? op)) op))
     (cond
       [p (record-problem-comment! ctx p)]
       [(and (memq h '(jmp call))
             (= 2 (length item))
             (or (loko-memory? (cadr item))
                 (and (symbol? (cadr item))
                      (register-name? (cadr item)))))
        (list (list (if (eq? h 'jmp) 'jmp-indirect 'call-indirect)
                    (car ops)))]
       [(eq? h 'sal) (list (cons 'shl ops))]
       [(eq? h 'movsxd) (list (cons 'movsx ops))]
       [else (list (cons h ops))])]))

(define (translate-item ctx item)
  (cond
    [(not (form? item)) (list item)]
    [else
     (define h (car item))
     (case h
       [(%label) (translate-label ctx item)]
       [(%comment) (list (cons 'comment (cdr item)))]
       [(%align) (translate-align ctx item)]
       [(%u8 %u16 %u32 %u64 %u128) (translate-integer-data ctx item)]
       [(%vu8) (translate-vu8 ctx item)]
       [(%utf8z) (translate-utf8z ctx item)]
       [(%equiv) '()]
       [(%section %origin %comm %mode %call)
        (record-problem-comment! ctx (problem 'directive-needs-image-layer item))]
       [else (translate-instruction ctx item)])]))

(define loko-directive?
  (let ([hs '(%label %comment %align %u8 %u16 %u32 %u64 %u128
               %vu8 %utf8z %equiv %section %origin %comm %mode %call)])
    (lambda (x)
      (and (form? x) (memq (car x) hs) #t))))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (translate-loko-source src)
  (define-values (text data) (loko-source-parts src))
  (let ([ctx (ctx (make-hash) (make-hash) (make-hash) '() 0)])

    ;; Definitions are collected first: code may refer to an alias that is
    ;; defined in the data half (e.g. codegen's initial-pcb-length).
    (for ([it (in-list text)]) (collect-equiv! ctx it))
    (for ([it (in-list data)]) (collect-equiv! ctx it))

    (define alias-names
      (sort (hash-keys (ctx-raw-aliases ctx))
            (lambda (a b) (string<? (format "~s" a) (format "~s" b)))))
    (for ([name (in-list alias-names)])
      (define v (resolve-alias ctx name '()))
      (when (problem? v) (record-problem! ctx v)))

    (define program-items
      (append* (for/list ([it (in-list text)]) (translate-item ctx it))))
    (define data-items
      (append* (for/list ([it (in-list data)]) (translate-item ctx it))))

    (define aliases
      (for/list ([name (in-list alias-names)])
        (define v (resolve-alias ctx name '()))
        (list 'alias name (if (problem? v) (problem->comment-form v) v))))

    (list 'loko-compat
          (cons 'program-items program-items)
          (cons 'data-items data-items)
          (cons 'aliases aliases)
          (cons 'problems (map problem->sexp (reverse (ctx-problems ctx)))))))
