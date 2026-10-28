#lang racket
;;; expand-pseudo-test.rkt -- 伪指令替换表

(require rackunit
         "helpers.rkt"
         (only-in "../riscv-compiler-rebuild/expand-pseudo/rewrite.rkt"
                  rewrite-program rewrite-tree expand-item apply-rule
                  pseudo-name? rules-for check-rows make-table
                  pseudo-leftover? fully-rewritten?
                  rewrite-rows directive-heads
                  pattern-var? pat-match subst))

(define (rw x) (rewrite-program x))

;; ---------------------------------------------------------------------------
;; 逐条规则: 每个名字、每种形状都能命中; 别名共用同一组规则
;; ---------------------------------------------------------------------------

(define (vars-in x)
  (cond
    [(pattern-var? x) (list x)]
    [(pair? x) (append* (map vars-in x))]
    [else '()]))

(define (all-vars vars)
  (for/list ([v (in-list (remove-duplicates vars))] [i (in-naturals)])
    (cons v (string->symbol (format "op~a" i)))))

(for ([row (in-list rewrite-rows)])
  (define names (takef row symbol?))
  (define rules (dropf row symbol?))
  (check-true (pair? names) (format "row has names: ~e" row))
  (for ([name (in-list names)])
    (check-true (pseudo-name? name)
                (format "~a is registered" name)))
  (for ([rule (in-list rules)])
    (define pat (car rule))
    (define tmpl (cadr rule))
    (define bindings (all-vars (vars-in pat)))
    (define actual (cons (car names) (subst pat bindings)))
    (check-equal? (apply-rule actual) (subst tmpl bindings)
                  (format "rule ~e / ~e" pat tmpl))
    ;; 别名平级: 换一个名字, 展开结果只换头以外的部分
    (for ([name (in-list (cdr names))])
      (check-equal? (apply-rule (cons name (subst pat bindings)))
                    (subst tmpl bindings)
                    (format "alias ~a for ~e" name pat)))))

;; 表自身没有重名/保留字冲突
(check-rows)
(check-true (andmap symbol? directive-heads))

;; ---------------------------------------------------------------------------
;; 典型替换: 加载 / 存储 / move / 缺的那半分支 / nop
;; ---------------------------------------------------------------------------

(check-equal? (expand-item '(load-32 t0 sp 8)) '(lwu t0 sp 8))
(check-equal? (expand-item '(l32 t0 sp 8)) '(lwu t0 sp 8))
(check-equal? (expand-item '(load-8 t0 a)) '(lbu t0 a 0))       ; 偏移补 0
(check-equal? (expand-item '(l8 t0 a)) '(lbu t0 a 0))
(check-equal? (expand-item '(load-s16 t0 a 4)) '(lh t0 a 4))
(check-equal? (expand-item '(load-64 t0 a 8)) '(ld t0 a 8))

(check-equal? (expand-item '(store-32 t0 a 4)) '(sw t0 a 4))
(check-equal? (expand-item '(st64 ra sp)) '(sd ra sp 0))
(check-equal? (expand-item '(store-8 s a)) '(sb s a 0))

(check-equal? (expand-item '(move a0 a1)) '(add a0 a1 x0))
(check-equal? (expand-item '(mv a0 a1)) '(add a0 a1 x0))

(check-equal? (expand-item '(ble a b L)) '(bge b a L))
(check-equal? (expand-item '(bgt a b L)) '(blt b a L))
(check-equal? (expand-item '(bleu a b L)) '(bgeu b a L))
(check-equal? (expand-item '(bgtu a b L)) '(bltu b a L))

(check-equal? (expand-item '(nop)) '(addi x0 x0 0))
(check-equal? (expand-item '(c.nop)) '(c.addi x0 0))

;; 形状不匹配: 保留原拼写, 不报错
(check-equal? (expand-item '(load-32 t0)) '(load-32 t0))
(check-equal? (expand-item '(l8 t0 a 0 extra)) '(l8 t0 a 0 extra))

;; 操作数是值: 不进去
(check-equal? (expand-item '(move t0 (load-32 t1 sp 8)))
              '(add t0 (load-32 t1 sp 8) x0))
(check-equal? (expand-item '(jal x0 (l8 foo))) '(jal x0 (l8 foo)))

;; ---------------------------------------------------------------------------
;; 遍历 / 透传 / 幂等
;; ---------------------------------------------------------------------------

(check-equal? (rw '((load-32 t0 sp 8) (store-64 ra sp 16)))
              '((lwu t0 sp 8) (sd ra sp 16)))
(check-equal? (rw '((add t0 t1 t2) (lb t0 t1 0) (li t0 42) (ecall)))
              '((add t0 t1 t2) (lb t0 t1 0) (li t0 42) (ecall)))
(check-equal? (rw '((quote (load-32 t0 sp 8))))
              '((quote (load-32 t0 sp 8))))
(check-equal? (rw '()) '())
(check-equal? (rw '(begin)) '())

(define once (rw '((l8 t0 a) (ble a b L) (move a0 a1))))
(check-equal? (rw once) once)
(check-false (pseudo-leftover? once))
(check-true (fully-rewritten? once))

;; ---------------------------------------------------------------------------
;; 表工具: 自环保护 / 形状校验 / 自定义表
;; ---------------------------------------------------------------------------

;; 表里写出自环: 建表不报, 展开时也不会卡死
(define t-loop (make-table '((loop ((?d) (loop ?d))))))
(check-error "self-cycle"
             (lambda () (expand-item '(loop t0) t-loop)))

(define t-pingpong
  (make-table '((ping ((?d) (pong ?d)))
                (pong ((?d) (ping ?d))))))
(check-error "mutual cycle"
             (lambda () (expand-item '(ping t0) t-pingpong)))

;; 形状错误 / 保留字 / 重名, 建表时就报
(check-error "rule shape" (lambda () (check-rows '((a ((?x) (b ?x) extra))))))
(check-error "empty rule" (lambda () (check-rows '((a)))))
(check-error "bad template" (lambda () (check-rows '((a ((?x) foo))))))
(check-error "reserved" (lambda () (check-rows '((label ((?x) (foo ?x)))))))
(check-error "duplicate spelling"
             (lambda () (check-rows '((a ((?x) (foo ?x)))
                                      (a ((?x) (bar ?x)))))))

(define t-custom
  (make-table '((inc add1 ((?x) (addi ?x ?x 1))))))
(check-equal? (expand-item '(inc a0) t-custom) '(addi a0 a0 1))
(check-equal? (expand-item '(add1 a0) t-custom) '(addi a0 a0 1))
(check-true (pseudo-name? 'inc t-custom))
(check-false (pseudo-name? 'inc))

;; 模式匹配: 同一变量必须匹配同一个值
(check-not-false (pat-match '(?x ?x) '(a a)))
(check-false (pat-match '(?x ?x) '(a b)))

(finish-tests "expand-pseudo")
