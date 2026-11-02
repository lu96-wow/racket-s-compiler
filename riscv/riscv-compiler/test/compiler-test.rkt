#lang racket
;;; test/compiler-test.rkt
;;;
;;; 汇编器契约测试:
;;;   - native 是默认基础语法
;;;   - 便利别名是另一个可选层
;;;   - analyze / relax / encode 不再假设“目标在最后一个操作数”

(require rackunit
         (only-in "../flow/flow.rkt"
                  run-flow flow-value default-flow)
         (only-in "../target.rkt" target-rv64-base)
         (only-in "../layout/layout.rkt" layout-problems)
         (only-in "../analyze/insn.rkt"
                  jump-target jump-target-position jump-register)
         (only-in "../encode/syntax/coverage.rkt" syntax-coverage))

(define target target-rv64-base)

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (seg-of build name)
  (findf (lambda (s)
           (eq? (cadr (assoc 'name (cdr s))) name))
         (cdr build)))

(define (seg-size build name)
  (cadr (assoc 'size (cdr (seg-of build name)))))

(define (seg-bytes build name)
  (for/list ([b (in-bytes (cadr (assoc 'bytes (cdr (seg-of build name)))))]) b))

(define (run-code selector src spec [rich '()])
  (run-flow target selector
            (list (cons 'rich-data rich)
                  (cons 'program-items src)
                  (cons 'layout-spec spec))))

(define code-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4)))
    (place c (main) (hot) (end))))

(define native-src
  '((label main)
    (sw 8 sp t0)
    (beq (hot) a0 a1)
    (jal x0 (end))
    (label hot)
    (ld t0 sp 8)
    (jalr x0 ra 0)
    (label end)
    (jalr x0 ra 0)))

;; golden bytes：native 写法逐字节对照。
(define expected-code-bytes
  '(35 36 81 0
    99 4 181 0
    111 0 192 0
    131 50 129 0
    103 128 0 0
    103 128 0 0))

;; ---------------------------------------------------------------------------
;; native 是默认流
;; ---------------------------------------------------------------------------

(check-false (memq 'expand-pseudo default-flow))

(define native-out (run-code default-flow native-src code-spec))
(check-equal? (layout-problems (flow-value native-out 'bound-layout)) '())
(check-equal? (seg-size (flow-value native-out 'build) 'c) 24)
(check-equal? (seg-bytes (flow-value native-out 'build) 'c) expected-code-bytes)

;; ---------------------------------------------------------------------------
;; native 分支操作数位置
;; ---------------------------------------------------------------------------

(check-equal? (jump-target '(beq (L) a0 a1)) '(L))
(check-equal? (jump-target '(ble (L) a0 a1)) '(L))
(check-equal? (jump-target '(beqz (L) a0)) '(L))
(check-equal? (jump-target '(c.beqz a0 (L))) '(L))
(check-equal? (jump-target '(j (L))) '(L))
(check-equal? (jump-target '(jal ra (L))) '(L))

(check-equal? (jump-target-position '(beq (L) a0 a1)) 0)
(check-equal? (jump-target-position '(c.beqz a0 (L))) 1)
(check-equal? (jump-target-position '(jal ra (L))) 1)
(check-equal? (jump-target-position '(j (L))) 0)

(check-equal? (jump-register '(jal ra (L))) 'ra)
(check-equal? (jump-register '(j (L))) 'x0)
(check-equal? (jump-register '(jalr x0 ra 0)) 'x0)

;; ---------------------------------------------------------------------------
;; native pseudo 分支也能松弛
;; ---------------------------------------------------------------------------

(define far-src
  '((label main)
    (ble (far) a0 a1)
    (label hot)
    (jalr x0 ra 0)
    (label far)
    (jalr x0 ra 0)))

(define far-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
              (segment (name d) (kind code) (start #x10000) (end #x11000) (align 4)))
    (place c (main) (hot))
    (place d (far))))

(define far-out (run-code default-flow far-src far-spec))
(check-equal? (layout-problems (flow-value far-out 'bound-layout)) '())
(check-equal? (seg-size (flow-value far-out 'build) 'c) 12)

;; ---------------------------------------------------------------------------
;; 便利别名是可选层，模板已经是 native 顺序
;; ---------------------------------------------------------------------------

(define alias-src
  '((label main)
    (store-8 8 sp t0)
    (load-8 t1 sp 8)
    (move a0 t1)
    (jalr x0 ra 0)))

(define alias-flow
  '(expand-data flatten expand-pseudo analyze dce relax bind-labels encode))

(define alias-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4)))
    (place c (main))))

(define alias-out (run-code alias-flow alias-src alias-spec))
(check-equal? (flow-value alias-out 'program-items)
              '((label main)
                (sb 8 sp t0)
                (lbu t1 sp 8)
                (add a0 t1 x0)
                (jalr x0 ra 0)))

;; ---------------------------------------------------------------------------
;; 数据 / li / la 不受顺序重构影响
;; ---------------------------------------------------------------------------

(define lit-src
  '((label main)
    (li t0 #x12345678)
    (la t1 (d t))
    (jalr x0 ra 0)))

(define lit-rich
  '((label d t)
    (utf-stringz "x")))

(define lit-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
              (segment (name d) (kind data) (start #x8000) (end #x9000) (align 8)))
    (place c (main))
    (place d (d t))))

(define lit-out (run-code default-flow lit-src lit-spec lit-rich))
(check-equal? (seg-size (flow-value lit-out 'build) 'c) 20)
(check-equal? (seg-size (flow-value lit-out 'build) 'd) 2)
(check-equal? (seg-bytes (flow-value lit-out 'build) 'd) '(120 0))

;; ---------------------------------------------------------------------------
;; native 覆盖应当是完整的
;; ---------------------------------------------------------------------------

(check-equal? (hash-ref (syntax-coverage) 'native-missing) 0)

(displayln "compiler tests: ok")
