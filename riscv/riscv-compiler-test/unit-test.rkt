#lang racket
;;; unit-test.rkt -- 布局前接口 (unit)

(require rackunit
         "helpers.rkt"
         (rename-in "../riscv-compiler/flow/flow.rkt" [run-flow run-flow*])
         (only-in "../riscv-compiler/target.rkt" target-rv64-base))

(define test-target target-rv64-base)
(define (run selector [seeds '()]) (run-flow* test-target selector seeds))

(define src
  '((module a
      (provide f point)
      (label f)
      (jalr x0 ra 0)
      (struct point (x b32) (y b32)))))

(define spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4)))
    (place c (a f))))

(define ctx
  (run default-flow
       (list (cons 'program-items src)
             (cons 'rich-data '())
             (cons 'layout-spec spec))))

(define unit (flow-value ctx 'unit))
(define build (flow-value ctx 'build))

(check-equal? unit
              '(unit
                (format 1)
                (target rv64)
                (modules
                 (module (a)
                   (provide (label (f) (a f) function))
                   (provide (struct (point) (a point)))))
                (declarations
                 (label (a f) function)
                 (struct (a point) (x b32) (y b32)))))

;; unit 是布局前的：没有地址、offset、size、segment bytes。
(check-false (for/or ([x (in-list (cdr unit))])
               (memq (car x) '(link segment))))
(define decls (cdr (assoc 'declarations (cdr unit))))
(check-false (for/or ([d (in-list decls)])
               (and (eq? (car d) 'struct)
                    (for/or ([part (in-list (cddr d))])
                      (memq (car part) '(offset size))))))

;; build 保留布局结果，同时带 unit。
(check-equal? (assoc 'unit (cdr build)) (cons 'unit (cdr unit)))
(check-equal? (build-size build 'c) 4)

(finish-tests "unit")
