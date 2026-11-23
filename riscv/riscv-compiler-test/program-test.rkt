#lang racket
;;; program-test.rkt -- 最终 (program (internal ...) (external ...)) 形状

(require rackunit
         "helpers.rkt"
         (rename-in "../riscv-compiler/flow/flow.rkt" [run-flow run-flow*])
         (only-in "../riscv-compiler/target.rkt" target-rv64-base))

(define test-target target-rv64-base)
(define (run seeds) (run-flow* test-target default-flow seeds))

(define a-src
  '((module a
      (provide f point)
      (label f)
      (jalr x0 ra 0)
      (struct point (x b32) (y b32)))))

(define a-rich
  '((label d table)
    (b32 1)))

(define a-spec
  '((origin #x80000000)
    (segments (segment (name c) (kind code) (start #x80001000) (end #x80001100) (align 4))
              (segment (name d) (kind data) (start #x80002000) (end #x80002100) (align 4)))
    (place c (a f))
    (place d (d table))))

(define a-ctx
  (run (list (cons 'program-items a-src)
             (cons 'rich-data a-rich)
             (cons 'layout-spec a-spec))))

(define a-program (flow-value a-ctx 'program))
(define a-internal (cadr a-program))
(define a-external (caddr a-program))

(check-equal? (car a-program) 'program)
(check-equal? (car a-internal) 'internal)
(check-equal? (car a-external) 'external)

(check-equal? (cdr (assoc 'modules (cdr a-internal)))
              '((module a
                  (base #x80000000)
                  (provide (label (f) (a f) function))
                  (provide (struct (point) (a point))))))

(check-equal? (cdr (assoc 'rich-data (cdr a-internal)))
              '((struct (a point) (x b32) (y b32))
                (data (d table) (value 4 1))))

(check-equal? (cdr (assoc 'functions (cdr a-internal)))
              '((function ((a f)) (body (jalr x0 ra 0)))))

(check-equal? (cdr (assoc 'offsets (cdr a-internal)))
              '((offset (a f) 4096)
                (offset (d table) 8192)))

(check-equal? (cdr (assoc 'modules (cdr a-external))) '())
(check-equal? (cdr (assoc 'rich-data (cdr a-external))) '())
(check-equal? (cdr (assoc 'functions (cdr a-external))) '())
(check-equal? (cdr (assoc 'offsets (cdr a-external))) '())

;; B 用 extern-units 消费 A：internal 只有 b，external 有 a。
(define a-build (flow-value a-ctx 'build))
(define b-src
  '((module b
      (require a)
      (label main)
      (jal x0 (f)))))

(define b-spec
  '((origin #x80002000)
    (segments (segment (name c) (kind code) (start #x80002000) (end #x80002100) (align 4)))
    (place c (b main))))

(define b-program
  (flow-value
   (run (list (cons 'extern-units (list (build-unit a-build)))
              (cons 'externs (list (build-link a-build)))
              (cons 'program-items b-src)
              (cons 'rich-data '())
              (cons 'layout-spec b-spec)))
   'program))

(define b-internal (cadr b-program))
(define b-external (caddr b-program))

(check-equal? (cdr (assoc 'modules (cdr b-internal))) '((module b (base #x80002000) (require (a)))))
(check-equal? (cdr (assoc 'functions (cdr b-internal)))
              '((function ((b main)) (body (jal x0 (a f))))))
(check-equal? (cdr (assoc 'offsets (cdr b-internal)))
              '((offset (b main) 0)))

(check-equal? (cdr (assoc 'modules (cdr b-external)))
              '((module a
                  (base #x80000000)
                  (provide (label (f) (a f) function))
                  (provide (struct (point) (a point))))))
(check-equal? (cdr (assoc 'functions (cdr b-external)))
              '((function (a f))))
(check-equal? (cdr (assoc 'offsets (cdr b-external)))
              '((offset (a f) 4096)))

(finish-tests "program")
