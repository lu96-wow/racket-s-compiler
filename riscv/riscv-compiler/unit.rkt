#lang racket/base

;;; unit.rkt
;;;
;;; 布局前接口（unit）。
;;;
;;; unit 只描述“名字 / 模块可见性 / 类型 / struct 声明”，不包含：
;;;   * 绝对地址
;;;   * struct 的 offset / size
;;;   * segment 字节
;;;
;;; 这些属于 image（build 的布局结果）。跨项目 require/provide 应该绑 unit，
;;; 而不是把上一份 image 的布局结果当接口。

(require racket/list
         "sexp.rkt"
         "meta.rkt"
         "target.rkt"
         "modules.rkt"
         "struct-meta.rkt"
         (only-in "analyze/analyze.rkt" program-blocks block-items block-head))

(provide make-unit
         unit-form?
         parse-units
         unit-target
         unit->struct-decls
         unit->label-provides
         unit->struct-provides
         unit->label-kinds
         unit->label-decls
         unit->root-module
         unit-label-declarations
         unit-struct-declarations)

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (sort-chains xs)
  (sort (remove-duplicates xs) chain<?))

;; ---------------------------------------------------------------------------
;; label 类型
;;
;; 这里不需要 layout：program 的块是 code，data-items 的 label 是 data。
;; 如果某个 provide 的名字两边都找不到，记 unknown。
;; ---------------------------------------------------------------------------

(define (collect-label-kinds program data-items)
  (define h (make-hash))
  (for ([b (in-list (program-blocks program))])
    (for ([l (in-list (block-head b))])
      (hash-set! h l 'function))
    (for ([it (in-list (block-items b))]
          #:when (label-form? it))
      (for ([l (in-list (cdr it))])
        (hash-set! h l 'function))))
  (for ([it (in-list data-items)]
        #:when (label-form? it))
    (for ([l (in-list (cdr it))])
      (hash-set! h l 'data)))
  h)

(define (label-kind h chain)
  (hash-ref h chain 'unknown))

;; ---------------------------------------------------------------------------
;; struct 声明
;; ---------------------------------------------------------------------------

(define (unit-struct-declarations structs)
  (for/list ([def (in-list structs)])
    (sdef->decl (parse-sdef def))))

;; ---------------------------------------------------------------------------
;; 模块 provide
;; ---------------------------------------------------------------------------

(define (module-rows->unit labels structs requires label-kinds)
  (define scopes
    (sort (remove-duplicates
           (append (hash-keys labels) (hash-keys structs) (hash-keys requires)))
          chain<?))
  (for/list ([scope (in-list scopes)])
    (define lrows
      (for/list ([p (in-list (hash-ref labels scope '()))])
        (list 'label (car p) (cdr p) (label-kind label-kinds (cdr p)))))
    (define srows
      (for/list ([p (in-list (hash-ref structs scope '()))])
        (list 'struct (car p) (cdr p))))
    (cons 'module
          (cons scope
                (append (hash-ref requires scope '())
                        (for/list ([row (in-list (append lrows srows))])
                          (list 'provide row)))))))

;; ---------------------------------------------------------------------------
;; label 声明
;; ---------------------------------------------------------------------------

(define (unit-label-declarations labels label-kinds)
  (define chains
    (sort-chains
     (append* (for/list ([(scope rows) (in-hash labels)])
                (for/list ([p (in-list rows)]) (cdr p))))))
  (for/list ([chain (in-list chains)])
    (list 'label chain (label-kind label-kinds chain))))

;; ---------------------------------------------------------------------------
;; 从 unit 取跨项目绑定所需的东西
;; ---------------------------------------------------------------------------

(define (unit-form? x)
  (and (form? x) (eq? (car x) 'unit)))

(define (parse-units datum)
  (cond
    [(null? datum) '()]
    [(unit-form? datum) (list datum)]
    [(and (form? datum) (eq? (car datum) 'build))
     (define row (assq 'unit (cdr datum)))
     (if row (parse-units (list (cons 'unit (cdr row)))) '())]
    [(and (list? datum) (andmap unit-form? datum)) datum]
    [else (error 'unit "extern-units 只接受 (unit ...) / (build ...) / unit 列表: ~e" datum)]))

(define (unit-target unit)
  (tag-ref 'unit unit 'target))

(define (unit-declaration-rows unit)
  (define row (assq 'declarations (cdr unit)))
  (if row (cdr row) '()))

(define (unit-module-rows unit)
  (define row (assq 'modules (cdr unit)))
  (if row (cdr row) '()))

(define (unit->struct-decls units)
  (append*
   (for/list ([unit (in-list units)])
     (for/list ([d (in-list (unit-declaration-rows unit))]
                #:when (and (form? d) (eq? (car d) 'struct)))
       d))))

(define (unit->label-provides units)
  (for/list ([row (in-list (append* (for/list ([unit (in-list units)])
                                      (unit-module-rows unit))))])
    (define labels
      (for/list ([p (in-list (cddr row))]
                 #:when (and (form? p) (eq? (car p) 'provide)
                             (form? (cadr p)) (eq? (car (cadr p)) 'label)))
        (define l (cadr p))
        (list 'provide (cadr l) (caddr l))))
    (cons 'module (cons (cadr row) labels))))

(define (unit->struct-provides units)
  (for/list ([row (in-list (append* (for/list ([unit (in-list units)])
                                      (unit-module-rows unit))))])
    (define structs
      (for/list ([p (in-list (cddr row))]
                 #:when (and (form? p) (eq? (car p) 'provide)
                             (form? (cadr p)) (eq? (car (cadr p)) 'struct)))
        (define s (cadr p))
        (list 'provide (cadr s) (caddr s))))
    (cons 'module (cons (cadr row) structs))))

;; project = 一个顶层 module。一个 unit 的模块树收敛成一个根 module。
;; 多个顶层 module 时，根是匿名 module ()，它们作为子 module 挂进去。
(define (unit->root-module unit)
  (define rows (unit-module-rows unit))
  (define by-scope (make-hash))
  (for ([row (in-list rows)])
    (hash-set! by-scope (cadr row) (cddr row)))
  (define scopes (hash-keys by-scope))
  (define (parent s) (if (null? s) #f (drop-right s 1)))
  (define top
    (sort (for/list ([s (in-list scopes)]
                     #:when (not (hash-has-key? by-scope (parent s))))
            s)
          chain<?))
  (define root-scope
    (cond
      [(null? scopes) '()]
      [(= 1 (length top)) (car top)]
      [else '()]))
  (define (children-of scope)
    (sort (remove-duplicates
           (for/list ([s (in-list scopes)]
                      #:when (equal? (parent s) scope)
                      #:unless (equal? s scope))
             s))
          chain<?))
  (define (build scope)
    (define name (if (null? scope) '() (last scope)))
    (define provides (hash-ref by-scope scope '()))
    (cons 'module
          (cons name
                (append provides
                        (map build (children-of scope))))))
  (build root-scope))

(define (unit->label-decls units)
  (append*
   (for/list ([unit (in-list units)])
     (for/list ([d (in-list (unit-declaration-rows unit))]
                #:when (and (form? d) (eq? (car d) 'label) (>= (length d) 3)))
       d))))

(define (unit->label-kinds units)
  (define h (make-hash))
  (for ([unit (in-list units)])
    (for ([d (in-list (unit-declaration-rows unit))]
          #:when (and (form? d) (eq? (car d) 'label) (>= (length d) 3)))
      (hash-set! h (cadr d) (caddr d))))
  h)

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (make-unit target program data-items
                   structs label-provides struct-provides module-requires)
  (define label-kinds (collect-label-kinds program data-items))
  (define labels
    (parse-extern-provides label-provides 'label-provides))
  (define struct-provides-hash
    (parse-extern-provides struct-provides 'struct-provides))
  (define requires
    (parse-extern-requires module-requires 'module-requires))
  (list 'unit
        (list 'format 1)
        (list 'target (target-xlen target))
        (cons 'modules
              (module-rows->unit labels struct-provides-hash requires label-kinds))
        (cons 'declarations
              (append (unit-label-declarations labels label-kinds)
                      (unit-struct-declarations structs)))))
