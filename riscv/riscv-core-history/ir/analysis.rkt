#lang racket
;;; ir/analysis.rkt
;;;
;;; 从已验证的 func 里读声明和约束。只做列表/哈希操作，不改 IR。
;;;
;;; 这一层只关心：
;;;   - vreg 声明；
;;;   - alloc 里的 pin / reserve；
;;;   - 代码里实际出现过的 vreg。
;;;
;;; 它不做 liveness，不做分配，不做 machine lowering。

(require racket/list
         "../core/sexp.rkt"
         "shape.rkt")

(provide func-vreg-decls
         func-vreg-table
         func-pins
         func-reserved
         func-clobbered
         func-asm-clobbered
         func-used-vregs)

;; (listof decl)，保持源码顺序；没有 vregs form 时返回 '()。
(define (func-vreg-decls func)
  (define form
    (findf (lambda (x) (and (form? x) (eq? (car x) 'vregs)))
           (cddr func)))
  (if form (cdr form) '()))

(define (func-vreg-table func)
  (for/hash ([decl (in-list (func-vreg-decls func))])
    (values (car decl) decl)))

(define (func-alloc-form func)
  (findf (lambda (x) (and (form? x) (eq? (car x) 'alloc)))
         (cddr func)))

;; vreg -> (native xN)
(define (func-pins func)
  (define form (func-alloc-form func))
  (define table (make-hash))
  (when form
    (for ([entry (in-list (cdr form))])
      (when (pin-entry? entry)
        (hash-set! table (cadr entry) (caddr entry)))))
  table)

;; (native xN) -> #t
(define (func-reserved func)
  (define form (func-alloc-form func))
  (define table (make-hash))
  (when form
    (for ([entry (in-list (cdr form))])
      (when (reserve-entry? entry)
        (hash-set! table (cadr entry) #t))))
  table)

;; (native xN) -> #t；clobber 是本函数内调用的保守并集。
(define (func-clobbered func)
  (define form (func-alloc-form func))
  (define table (make-hash))
  (when form
    (for ([entry (in-list (cdr form))])
      (when (clobber-entry? entry)
        (for ([reg (in-list (cdr entry))])
          (hash-set! table reg #t)))))
  table)

;; inline asm 的 clobber 并集。分配器保守地把它当作全局不可用寄存器。
(define (func-asm-clobbered func)
  (define table (make-hash))
  (for ([block (in-list (filter (lambda (x) (and (form? x) (eq? (car x) 'block)))
                                (cddr func)))])
    (for ([op (in-list (cddr block))])
      (when (and (form? op) (eq? (car op) 'asm))
        (define clause (assoc 'clobber (cdr op)))
        (when clause
          (for ([reg (in-list (cdr clause))])
            (hash-set! table reg #t))))))
  table)

;; 代码里出现过的 vreg，按首次出现顺序返回。
;; vregs / alloc / entry 是声明和约束，不算 use。
;; asm 只算 inputs / outputs；code 是封闭 machine 块。
(define (func-used-vregs func)
  (define seen (make-hash))
  (define order '())

  (define (add! vreg)
    (unless (hash-has-key? seen vreg)
      (hash-set! seen vreg #t)
      (set! order (cons vreg order))))

  (define (walk x)
    (cond
      [(vreg? x)
       (add! x)]
      [(and (form? x) (eq? (car x) 'asm))
       (for ([clause (in-list (cdr x))])
         (when (and (form? clause) (memq (car clause) '(inputs outputs)))
           (for ([entry (in-list (cdr clause))])
             (when (and (form? entry) (pair? (cdr entry)))
               (walk (car entry))))))]
      [(form? x)
       (for-each walk x)]
      [else (void)]))

  (for ([item (in-list (cddr func))])
    (cond
      [(and (form? item) (memq (car item) '(vregs alloc entry)))
       (void)]
      [(and (form? item) (eq? (car item) 'block))
       (for ([x (in-list (cddr item))])
         (walk x))]
      [else (void)]))

  (reverse order))
