#lang racket/base

;;; program.rkt
;;;
;;; 最终对外 s-exp：
;;;
;;;   (program
;;;     (internal
;;;       (modules
;;;         (module main (base B) ...))
;;;       (rich-data ...)
;;;       (functions ...)
;;;       (offsets (offset (main f) offset) ...))
;;;     (external
;;;       (modules
;;;         (module lib (base B) ...))
;;;       (rich-data ...)
;;;       (functions ...)
;;;       (offsets (offset (lib g) offset) ...)))
;;;
;;; base 属于项目根 module；offsets 存相对 base 的偏移。
;;; internal 是本程序定义的；external 是本程序引用但不在本程序里的。

(require racket/list
         "sexp.rkt"
         "meta.rkt"
         "unit.rkt"
         (only-in "code.rkt" code-blocks block-head block-items)
         (only-in "externs.rkt" extern-link-tables))

(provide make-program
         program-internal
         program-external)

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (link-row build)
  (and (form? build) (assq 'link (cdr build))))

(define (link-rows build)
  (define row (link-row build))
  (if row (cddr row) '()))

(define (link-base build)
  (define row (link-row build))
  (if row (cadr row) '(base 0)))

(define (root-with-base root base)
  (cons 'module
        (cons (cadr root)
              (cons base (cddr root)))))

;; 连续 label + items 组成一个 data 块。
(define (split-data-runs items)
  (define runs '())
  (define cur-labels '())
  (define cur-items '())
  (define (flush!)
    (when (or (pair? cur-labels) (pair? cur-items))
      (set! runs (cons (list (reverse cur-labels) (reverse cur-items)) runs))
      (set! cur-labels '())
      (set! cur-items '())))
  (for ([it (in-list items)])
    (cond
      [(label-form? it)
       (when (pair? cur-items) (flush!))
       (set! cur-labels (append (reverse (cdr it)) cur-labels))]
      [else (set! cur-items (cons it cur-items))]))
  (flush!)
  (reverse runs))

(define (data-runs->sexp items)
  (for/list ([run (in-list (split-data-runs items))])
    (define labels (car run))
    (define body (cadr run))
    (cons 'data (cons labels body))))

(define (code-blocks->functions code)
  (for/list ([b (in-list (code-blocks code))])
    (list 'function (block-head b) (cons 'body (block-items b)))))

;; ---------------------------------------------------------------------------
;; 外部声明
;; ---------------------------------------------------------------------------

(define (external-units-decls extern-units)
  (define units (parse-units extern-units))
  (define label-decls (unit->label-decls units))
  (define struct-decls (unit->struct-decls units))
  (define data-decls
    (for/list ([d (in-list label-decls)]
               #:when (eq? (caddr d) 'data))
      (list 'data (cadr d))))
  (define function-decls
    (for/list ([d (in-list label-decls)]
               #:when (eq? (caddr d) 'function))
      (list 'function (cadr d))))
  (values function-decls data-decls struct-decls))

(define (external-offsets tables names)
  (define allowed (make-hash))
  (for ([n (in-list names)]) (hash-set! allowed n #t))
  (append*
   (for/list ([t (in-list tables)])
     (define base (car t))
     (define rows (cdr t))
     (for/list ([row (in-list rows)]
                #:when (hash-ref allowed (cadr row) #f))
       (list 'offset (cadr row)
             (and (caddr row) (- (caddr row) base)))))))

;; ---------------------------------------------------------------------------
;; internal / external
;; ---------------------------------------------------------------------------

(define (internal-unit unit code data-items build)
  (define decls-row (and (pair? unit) (assq 'declarations (cdr unit))))
  (define decls (if decls-row (cdr decls-row) '()))
  (define base (link-base build))
  (define base-value (cadr base))
  (list 'internal
        (cons 'modules
              (list (root-with-base
                     (if (pair? unit)
                         (unit->root-module unit)
                         '(module ()))
                     base)))
        (cons 'rich-data
              (append (for/list ([d (in-list decls)]
                                 #:when (eq? (car d) 'struct))
                        d)
                      (data-runs->sexp data-items)))
        (cons 'functions (code-blocks->functions code))
        (cons 'offsets
              (for/list ([row (in-list (link-rows build))])
                (list 'offset (cadr row)
                      (- (caddr row) base-value))))))

(define (external-section extern-units externs)
  (define units (parse-units extern-units))
  (define tables (extern-link-tables externs))
  (define roots0 (map unit->root-module units))
  (define root-names (map cadr roots0))
  (unless (= (length root-names) (length (remove-duplicates root-names)))
    (error 'program "external 项目根 module 重名: ~a" root-names))
  (define roots
    (for/list ([unit (in-list units)] [root (in-list roots0)])
      (define names
        (map cadr (unit->label-decls (list unit))))
      (define bases
        (for/list ([t (in-list tables)]
                   #:when (for/or ([row (in-list (cdr t))])
                            (member (cadr row) names)))
          (car t)))
      (define base
        (cond
          [(null? bases) 0]
          [else (car bases)]))
      (root-with-base root (list 'base base))))
  (define-values (functions data structs)
    (external-units-decls extern-units))
  (define names
    (append (map cadr functions) (map cadr data)))
  (list 'external
        (cons 'modules roots)
        (cons 'rich-data (append structs data))
        (cons 'functions functions)
        (cons 'offsets (external-offsets tables names))))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (make-program unit code data-items build extern-units externs)
  (list 'program
        (internal-unit unit code data-items build)
        (external-section extern-units externs)))

(define (program-internal p)
  (cadr p))

(define (program-external p)
  (caddr p))
