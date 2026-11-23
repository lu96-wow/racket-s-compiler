#lang racket
;;; code-test.rkt -- code(blocks + falls) / 前端 blockify / validate

(require rackunit
         "helpers.rkt"
         (only-in "../riscv-compiler/code.rkt"
                  code? code-blocks code-falls make-code
                  block-head block-items make-block
                  fall-from fall-to make-fall
                  code->sexp sexp->code)
         (only-in "../riscv-compiler/code/validate.rkt" validate-code))

(define items
  '((label main)
    (addi a0 a0 1)
    (label mark)                 ; 非目标: 位置标记
    (addi a1 a1 1)
    (beq (done) a0 a1)
    (addi a2 a2 1)               ; 无 label 的块
    (label done)
    (jalr x0 ra 0)))

(define c (code-of items))

(check-true (code? c))
(check-equal? (length (code-blocks c)) 3)
(check-equal? (block-head (list-ref (code-blocks c) 0)) '((main)))
(check-equal? (block-items (list-ref (code-blocks c) 0))
              '((addi a0 a0 1) (label mark) (addi a1 a1 1) (beq (done) a0 a1)))
(check-equal? (block-head (list-ref (code-blocks c) 1)) '())
(check-equal? (block-items (list-ref (code-blocks c) 1)) '((addi a2 a2 1)))
(check-equal? (block-head (list-ref (code-blocks c) 2)) '((done)))
(check-equal? (block-items (list-ref (code-blocks c) 2)) '((jalr x0 ra 0)))

;; 条件分支/普通指令落下；jalr x0 不落下
(check-equal? (code-falls c) '((fall 0 1) (fall 1 2)))

;; 连续多条 label 同属块头
(define c-head (code-of '((label a) (label b) (addi a0 a0 1))))
(check-equal? (block-head (car (code-blocks c-head))) '((a) (b)))

;; 目标 label 才切块
(define c-target (code-of '((label a) (jal x0 (b)) (label b) (jalr x0 ra 0))))
(check-equal? (map block-head (code-blocks c-target)) '(((a)) ((b))))

;; ---------------------------------------------------------------------------
;; 手工 code / 兼容旧 ((blocks ...) (flows ...))
;; ---------------------------------------------------------------------------

(define manual
  (make-code
   (list (make-block '((main)) '((addi a0 a0 1) (beq (done) a0 a1)))
         (make-block '((done)) '((jalr x0 ra 0))))
   (list (make-fall 0 1))))

(check-equal? (code-falls manual) '((fall 0 1)))
(check-equal? (fall-from (car (code-falls manual))) 0)
(check-equal? (fall-to (car (code-falls manual))) 1)
(check-equal? (sexp->code (code->sexp manual)) manual)

;; 旧 blocks+flows 字面量: 只保留 fallthrough
(define old-fields
  '((blocks
     (block ((main)) (addi a0 a0 1) (beq (done) a0 a1))
     (block ((done)) (jalr x0 ra 0)))
    (flows
     (flow (succ 1) (fallthrough 1) (root? #t))
     (flow (succ) (fallthrough #f) (root? #f)))))
(check-equal? (sexp->code old-fields) manual)

;; ---------------------------------------------------------------------------
;; validate
;; ---------------------------------------------------------------------------

(check-equal? (validate-code c) c)
(check-error "validate 拒绝省略 link 的 jal"
             (lambda ()
               (validate-code (code-of '((label g) (jal g))))))
(check-error "validate 要求 code"
             (lambda () (validate-code '((blocks) (falls)))))

(finish-tests "code")
