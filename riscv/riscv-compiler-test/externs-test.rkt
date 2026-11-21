#lang racket
;;; externs-test.rkt -- 输入侧的 link 表（外部符号）
;;;
;;; 锁住：
;;;   - 形状和产物里的 (link …) 一样，可以直接拿上一份编译的结果喂进来
;;;   - 外部名字在 flatten 放行；没有 externs 时仍然报 undefined label
;;;   - 地址参与距离判断 -> check 报 out-of-range / la-too-far；形式由前端显式选择
;;;   - 地址未知 -> unlinked-external（没有 reloc 层，不产出镜像）
;;;   - 和本地 label 撞名 -> external-conflict；奇数地址 -> misaligned-external
;;;   - 外部符号不进 link/provides（那不是本镜像提供的东西），但能在 encode 里解析

(require rackunit
         racket/list
         "helpers.rkt"
         (only-in "../riscv-compiler/flow/flow.rkt"
                  run-flow flow-value default-flow)
         (only-in "../riscv-compiler/target.rkt" target-rv64-base)
         (only-in "../riscv-compiler/layout/layout.rkt" layout-externs)
         (only-in "../riscv-compiler/externs.rkt"
                  parse-externs extern-rows extern-names))

(define target target-rv64-base)

(define spec
  '((origin #x1000)
    (segments (segment (name c) (kind code) (start #x1000) (end #x220000) (align 4)))
    (place c (main))))

(define (compile src externs [flow default-flow] [layout-spec spec])
  (run-flow target flow
            (list (cons 'rich-data '())
                  (cons 'program-items src)
                  (cons 'layout-spec layout-spec)
                  (cons 'externs externs))))

;; 另一份镜像: 段在别处, 段里只有它自己的 label
(define lib-spec
  '((origin #x8000)
    (segments (segment (name c) (kind code) (start #x8000) (end #x9000) (align 4)))
    (place c (lib f))))

(define (measured src externs)
  (flow-value (compile src externs '(expand-data flatten analyze dce layout check))
              'measured-layout))

(define (problems src externs) (cdr (assoc 'problems (measured src externs))))
(define (problem-kinds src externs) (map car (problems src externs)))

(define (uses-la) '((label main) (la-pcrel x10 (lib f)) (jalr x0 ra 0)))
(define (uses-la-pcrel-li-add) '((label main) (la-pcrel-li-add x10 x5 (lib f)) (jalr x0 ra 0)))
(define (calls)   '((label main) (beq (lib f) a0 a1) (jalr x0 ra 0)))
(define (calls-far)
  '((label main) (branch-auipc-jalr x5 beq a0 a1 (lib f)) (jalr x0 ra 0)))

;; ---------------------------------------------------------------------------
;; 形状解析
;; ---------------------------------------------------------------------------

(call-with-values (lambda ()
                    (parse-externs '((link (base #x80000000)
                                           (symbol (lib f) #x80001000)
                                           (symbol (lib g) #f)))))
  (lambda (bases rows)
    (check-equal? bases '(#x80000000))
    (check-equal? rows '((symbol (lib f) #x80001000) (symbol (lib g) #f)))))

;; base 可省
(check-equal? (extern-rows '((link (symbol (lib f) 4096)))) '((symbol (lib f) 4096)))
;; 多份表
(check-equal? (extern-names '((link (symbol (a f) 4096))
                              (link (symbol (b g) 8192))))
              '((a f) (b g)))
;; 空
(check-equal? (extern-rows '()) '())
;; 畸形
(check-error "不是 link" (lambda () (extern-rows '((symbol (a f) 4096)))))
(check-error "地址类型" (lambda () (extern-rows '((link (symbol (a f) "x"))))))
(check-error "行形状" (lambda () (extern-rows '((link (label (a f) 4096))))))

;; ---------------------------------------------------------------------------
;; flatten: 外部名字放行, 笔误仍然报错
;; ---------------------------------------------------------------------------

(check-true (list? (measured (uses-la) '((link (symbol (lib f) #x1800))))))
(check-exn exn:fail?
           (lambda () (measured (uses-la) '())))
(check-exn exn:fail?                      ; 名字写错, 外部表里没有
           (lambda () (measured '((label main) (la-pcrel x10 (lib nope)) (jalr x0 ra 0))
                                '((link (symbol (lib f) #x1800))))))

;; ---------------------------------------------------------------------------
;; 地址参与距离判断
;; ---------------------------------------------------------------------------

;; 近: 什么都不用升
(check-equal? (problems (uses-la) '((link (symbol (lib f) #x1800)))) '())
;; la 到 3 GiB 外: 近形式够不着 -> check 报 la-too-far；前端必须显式写 la-pcrel-li-add
(define far-externs '((link (symbol (lib f) #xC0000000))))
(check-equal? (problem-kinds (uses-la) far-externs) '(la-too-far))
(check-equal? (problems (uses-la-pcrel-li-add) far-externs) '())
;; 条件分支到 3 MiB 外: 4 字节 branch 够不着 -> check 报 out-of-range
(check-equal? (problem-kinds (calls) '((link (symbol (lib f) #x300000))))
              '(out-of-range))
;; 前端显式选 branch-auipc-jalr + scratch: check 通过
(check-equal? (problems (calls-far) '((link (symbol (lib f) #x300000)))) '())

;; ---------------------------------------------------------------------------
;; 错误情形
;; ---------------------------------------------------------------------------

;; 地址未知: 没有 reloc 层, 拒绝出产物(而不是编出一个“看着能跑”的镜像)
(check-equal? (problem-kinds (uses-la) '((link (symbol (lib f) #f))))
              '(unlinked-external))
;; 未知地址不再额外报 undefined-target(那不是“未定义”, 是“还不知道”)
(check-equal? (problems (uses-la) '((link (symbol (lib f) #f))))
              '((unlinked-external (lib f))))

;; 和本地 label 撞名
(check-equal? (problem-kinds '((label main) (jalr x0 ra 0))
                             '((link (symbol (main) #x1800))))
              '(external-conflict))

;; 奇数地址: branch/jal/jalr 都忽略 bit0, 不能当目标
(check-equal? (problem-kinds (uses-la) '((link (symbol (lib f) #x1801))))
              '(misaligned-external))

;; ---------------------------------------------------------------------------
;; 地址从输入传进产物: externs 原样带下去, 但不进 link/provides
;; ---------------------------------------------------------------------------

(define out (compile (uses-la) '((link (symbol (lib f) #x1800)))))
(define measured-layout (flow-value out 'measured-layout))
(check-equal? (layout-externs measured-layout)
              '((symbol (lib f) #x1800)))

(define build (flow-value out 'build))
(define link (findf (lambda (x) (eq? (car x) 'link)) (cdr build)))
(define provides (findf (lambda (x) (eq? (car x) 'provides)) (cdr build)))

;; 外部符号不是本镜像提供的东西: 两张表里都只有 main
(check-equal? (map cadr (cddr link)) '((main)))
(check-equal? (cdr provides) '((main)))

;; 但 encode 能解析它: la 的 8 字节里 auipc 的 hi/lo 指向 0x1800
(check-equal? (build-size build 'c) 12)

;; ---------------------------------------------------------------------------
;; 和产物里的 link 形状一致: 上一份的输出可以直接当这一份的输入
;; ---------------------------------------------------------------------------

(define lib-out
  (compile '((label lib f) (jalr x0 ra 0))
           '()
           '(expand-data flatten analyze dce layout check bind-labels encode)
           lib-spec))
(define lib-build (flow-value lib-out 'build))
(define lib-link (findf (lambda (x) (eq? (car x) 'link)) (cdr lib-build)))

;; 直接把 (link …) 当 externs 喂给下一份
(check-true (list? (measured (uses-la) (list lib-link))))
(check-equal? (let ([p (problems (uses-la) (list lib-link))]) p) '())

(finish-tests "externs")
