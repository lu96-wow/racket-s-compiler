#lang racket
;;; frontend/collect.rkt
;;;
;;; 第一步：只收集，不解析。
;;;
;;; 输入：(file 名字 form ...) 的列表。
;;; 输出：program —— 模块表、全局定义表、按源码顺序排好的顶层 unit。
;;;
;;; 这一层只关心：
;;;   - module / provide / require / func / data / raw 的壳；
;;;   - 哪些名字是定义；
;;;   - raw 内部的 label 也是全局名。
;;;
;;; 它不关心：哪个 require 能解出哪个名字、vreg、block、指令。

(require "sexp.rkt"
         "program.rkt")

(provide collect-program)

(define (collect-program files #:interface-files [interface-files '()])
  (define prog (program (make-hash) (make-hash) '()))
  (for ([file (in-list files)])
    (collect-file! prog file #f))
  (for ([file (in-list interface-files)])
    (collect-file! prog file #t))
  prog)

;; ---------------------------------------------------------------------------
;; 文件
;; ---------------------------------------------------------------------------

(define (collect-file! prog file interface?)
  (define-values (name forms)
    (match file
      [(list 'file (? source-name? n) fs ...) (values n fs)]
      [_ (error 'collect "expected (file name form ...): ~e" file)]))

  (define module-items (filter module-form? forms))
  (define def-items (filter root-definition-form? forms))
  (define other-items
    (filter (lambda (x) (not (or (module-form? x)
                                 (root-definition-form? x))))
            forms))

  (when (pair? other-items)
    (error 'collect
           "file ~a: top-level forms must be module / func / data / raw, got: ~e"
           name (car other-items)))

  (cond
    [(and (pair? module-items) (pair? def-items))
     (error 'collect
            "file ~a: cannot mix (module ...) and implicit-root func/data/raw"
            name)]
    [(pair? module-items)
     (for ([m (in-list module-items)])
       (collect-module! prog name m interface?))]
    [else
     (for ([it (in-list def-items)])
       (collect-root-item! prog name it interface?))]))

(define (root-definition-form? x)
  (or (func-form? x) (data-form? x) (raw-form? x)))

;; ---------------------------------------------------------------------------
;; 模块
;; ---------------------------------------------------------------------------

(define (collect-module! prog file-name form interface?)
  (define-values (name body)
    (match form
      [(list 'module (? chain? n) forms ...) (values n forms)]
      [_ (error 'collect "file ~a: malformed module form: ~e" file-name form)]))

  (define table (program-modules prog))
  (when (hash-has-key? table name)
    (error 'collect "module ~a is defined twice" (chain->string name)))

  (define m (module name '() '() '()))
  (hash-set! table name m)

  (for ([it (in-list body)])
    (cond
      [(module-form? it)
       (error 'collect
              "module ~a: nested modules are not supported in the first version"
              (chain->string name))]
      [(provide-form? it)
       (set-module-provides!
        m (append (module-provides m) (parse-provide file-name name it)))]
      [(require-form? it)
       (set-module-requires!
        m (append (module-requires m) (parse-require file-name name it)))]
      [(root-definition-form? it)
       (collect-definition! prog m it interface?)]
      [else
       (error 'collect
              "module ~a: expected provide / require / func / data / raw, got: ~e"
              (chain->string name) it)])))

(define (collect-root-item! prog file-name form interface?)
  (define m (ensure-root-module! prog))
  (cond
    [(func-form? form) (collect-definition! prog m form interface?)]
    [(data-form? form) (collect-definition! prog m form interface?)]
    [(raw-form? form) (collect-definition! prog m form interface?)]
    [else
     (error 'collect
            "file ~a: implicit root only accepts func / data / raw, got: ~e"
            file-name form)]))

(define (ensure-root-module! prog)
  (define table (program-modules prog))
  (define name '())
  (or (hash-ref table name #f)
      (let ([m (module name (list (provide-spec #f #f)) '() '())])
        (hash-set! table name m)
        m)))

;; ---------------------------------------------------------------------------
;; provide / require 子句
;; ---------------------------------------------------------------------------

;; (provide spec ...) -> (listof provide-spec)
(define (parse-provide file-name module-name form)
  (match form
    [(list 'provide specs ...)
     (append* (for/list ([spec (in-list specs)])
                (parse-provide-spec file-name module-name spec)))]
    [_ (error 'collect "file ~a: malformed provide: ~e" file-name form)]))

(define (parse-provide-spec file-name module-name spec)
  (cond
    [(eq? spec '*)
     (list (provide-spec #f #f))]

    [(and (form? spec) (eq? (car spec) 'rename-out))
     (match spec
       [(list 'rename-out pairs)
        (unless (list? pairs)
          (error 'collect
                 "file ~a: module ~a: rename-out needs a list of (local external) pairs: ~e"
                 file-name (chain->string module-name) spec))
        (for/list ([pair (in-list pairs)])
          (match pair
            [(list (? chain? local) (? chain? external))
             (provide-spec local external)]
            [_ (error 'collect
                      "file ~a: module ~a: rename-out pair must be ((local) (external)): ~e"
                      file-name (chain->string module-name) pair)]))]
       [_ (error 'collect
                 "file ~a: module ~a: malformed rename-out: ~e"
                 file-name (chain->string module-name) spec)])]

    [(chain? spec)
     (list (provide-spec spec spec))]

    [else
     (error 'collect
            "file ~a: module ~a: provide only accepts global name chains, *, or rename-out: ~e"
            file-name (chain->string module-name) spec)]))

;; (require spec ...) -> (listof require-spec)
(define (parse-require file-name module-name form)
  (match form
    [(list 'require specs ...)
     (for/list ([spec (in-list specs)])
       (parse-require-spec file-name module-name spec))]
    [_ (error 'collect "file ~a: malformed require: ~e" file-name form)]))

(define (parse-require-spec file-name module-name spec)
  (cond
    [(and (form? spec) (eq? (car spec) 'prefix-in))
     (match spec
       [(list 'prefix-in (? name? prefix) (? chain? target))
        (require-spec target prefix '())]
       [_ (error 'collect
                 "file ~a: module ~a: prefix-in needs (prefix-in p module-chain): ~e"
                 file-name (chain->string module-name) spec)])]

    [(and (form? spec) (eq? (car spec) 'rename-in))
     (match spec
       [(list 'rename-in (? chain? target) pairs)
        (unless (list? pairs)
          (error 'collect
                 "file ~a: module ~a: rename-in needs a list of (external local) pairs: ~e"
                 file-name (chain->string module-name) spec))
        (define renames
          (for/list ([pair (in-list pairs)])
            (match pair
              [(list (? chain? external) (? chain? local))
               (rename external local)]
              [_ (error 'collect
                        "file ~a: module ~a: rename-in pair must be ((external) (local)): ~e"
                        file-name (chain->string module-name) pair)])))
        (check-duplicate-renames! file-name module-name renames)
        (require-spec target #f renames)]
       [_ (error 'collect
                 "file ~a: module ~a: malformed rename-in: ~e"
                 file-name (chain->string module-name) spec)])]

    [(chain? spec)
     (require-spec spec #f '())]

    [else
     (error 'collect
            "file ~a: module ~a: require only accepts module chains, prefix-in, or rename-in: ~e"
            file-name (chain->string module-name) spec)]))

(define (check-duplicate-renames! file-name module-name renames)
  (define seen (make-hash))
  (for ([r (in-list renames)])
    (define external (rename-external r))
    (when (hash-has-key? seen external)
      (error 'collect
             "file ~a: module ~a: rename-in names ~a twice"
             file-name (chain->string module-name) (chain->string external)))
    (hash-set! seen external #t)))

;; ---------------------------------------------------------------------------
;; 定义
;; ---------------------------------------------------------------------------

(define (collect-definition! prog m form interface?)
  (define kind
    (cond
      [(func-form? form) 'func]
      [(data-form? form) 'data]
      [(raw-form? form) 'raw]
      [else (error 'collect "internal: not a definition form: ~e" form)]))

  (define rest (cdr form))
  (unless (and (pair? rest) (chain? (car rest)))
    (error 'collect
           "~a needs a global name chain: ~e"
           kind form))

  (define local (car rest))
  (define body (cdr rest))
  (define global (append (module-name m) local))

  (define defs (program-defs prog))
  (when (hash-has-key? defs global)
    (error 'collect "global name ~a is defined twice" (chain->string global)))

  (hash-set! defs global
             (definition kind (module-name m) local global interface?))
  (add-own-def! m local)

  ;; interface source 只提供名字/kind，不产生顶层 unit。
  (unless interface?
    (set-program-units!
     prog
     (cons (unit (module-name m) form global) (program-units prog))))

  (cond
    [(eq? kind 'raw) (collect-raw-labels! prog m global body interface?)]
    [(eq? kind 'data) (collect-data-labels! prog m global body interface?)]
    [else (void)]))

(define (add-own-def! m local)
  (unless (member local (module-own-defs m))
    (set-module-own-defs! m (append (module-own-defs m) (list local)))))

;; data 内部的 label 也是全局名。
;; 它们不产生独立 unit；输出时仍然留在 data body 里。
(define (collect-data-labels! prog m data-global body interface?)
  (for ([it (in-list body)])
    (when (and (form? it) (eq? (car it) 'label))
      (unless (and (pair? (cdr it)) (andmap chain? (cdr it)))
        (error 'collect
               "data ~a: label needs one or more name chains: ~e"
               (chain->string data-global) it))
      (for ([local (in-list (cdr it))])
        (define global (append (module-name m) local))
        (when (hash-has-key? (program-defs prog) global)
          (error 'collect "global name ~a is defined twice" (chain->string global)))
        (hash-set! (program-defs prog)
                   global
                   (definition 'data-label (module-name m) local global interface?))
        (add-own-def! m local)))))

;; raw 内部的 label 也是全局名：作用域和 raw 自己一样。
;; 它们不产生独立 unit；输出时仍然留在 raw body 里。
(define (collect-raw-labels! prog m raw-global body interface?)
  (for ([it (in-list body)])
    (cond
      [(and (form? it) (eq? (car it) 'label))
       (unless (label-form? it)
         (error 'collect
                "raw ~a: label needs one or more name chains: ~e"
                (chain->string raw-global) it))
       (for ([local (in-list (cdr it))])
         (define global (append (module-name m) local))
         (when (hash-has-key? (program-defs prog) global)
           (error 'collect "global name ~a is defined twice" (chain->string global)))
         (hash-set! (program-defs prog)
                    global
                    (definition 'raw-label (module-name m) local global interface?))
         (add-own-def! m local))]
      [else (void)])))
