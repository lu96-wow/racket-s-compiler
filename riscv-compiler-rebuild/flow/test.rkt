#lang racket
;;; flow/test.rkt -- 构建流

(require rackunit
         "flow.rkt"
         (only-in "../encode/encode.rkt" encode-layout)
         (only-in "../relax/relax.rkt" relax)
         (only-in "../dce/dce.rkt" eliminate-dead)
         (only-in "../analyze/analyze.rkt" analyze)
         (only-in "../layout/layout.rkt" layout-program))

;; ---------------------------------------------------------------------------
;; 素材
;; ---------------------------------------------------------------------------

(define src
  '((label main) (move a0 a1) (ble a0 a1 (hot)) (jal x0 (end))
    (label hot) (addi a0 a0 1) (jalr x0 ra 0)
    (label end) (ld t0 sp 8)))

(define rich '((label g tab) (value 8 (label+ (main) 0)) (utf-stringz "hi")))

(define layout-spec
  '((segments (segment c code #x100000 #x100FFF 16)
              (segment d data #x200000 #x200FFF 8))
    (place c (main) (hot) (end)) (place d (g tab))))

(define seeds
  (list (cons 'rich-data rich)
        (cons 'program-items src)
        (cons 'layout-spec layout-spec)))

;; 带死块的程序: 跑不跑 dce 结果不同
(define src-dead
  '((label main) (addi a0 a0 1) (jal x0 (end))
    (label dead) (addi a1 a1 1) (jalr x0 ra 0)
    (label end) (jalr x0 ra 0)))

(define spec-dead
  '((segments (segment c code #x100000 #x100FFF 16))
    (place c (main) (end))))

;; 同一个程序, 但数据段是空的
(define spec-code
  '((segments (segment c code #x100000 #x100FFF 16))
    (place c (main) (hot) (end))))

(define (bytes-of-seg build name)
  (define seg (findf (lambda (s) (equal? (cadr (assoc 'name (cdr s))) name)) (cdr build)))
  (bytes->list (cadr (assoc 'bytes (cdr seg)))))

;; ---------------------------------------------------------------------------
;; 阶段表
;; ---------------------------------------------------------------------------

(check-equal? (stage-names)
              '(analyze dce encode expand-data expand-pseudo flatten layout relax))

(check-equal? (providers-of 'layout) '(layout relax))
(check-equal? (providers-of 'build) '(encode))
(check-equal? (providers-of 'nope) '())

;; 平层: layout 和 relax 吃同一种输入、产同一种输出
(check-equal? (stage-requires (hash-ref stage-table 'layout))
              (stage-requires (hash-ref stage-table 'relax)))
(check-equal? (stage-provides (hash-ref stage-table 'layout))
              (stage-provides (hash-ref stage-table 'relax)))

;; ---------------------------------------------------------------------------
;; 默认流
;; ---------------------------------------------------------------------------

(define out (run-flow default-flow seeds))
(define build (flow-value out 'build))

(check-true (hash-has-key? out 'names))          ; flatten 的在途值
(check-true (hash-has-key? out 'program))
(check-true (hash-has-key? out 'layout))

;; 和手写的期望字节比
(check-equal? (bytes-of-seg build 'c)
              '(#x33 #x85 #x05 #x00     ; add a0,a1,x0
                #x63 #xD4 #xA5 #x00     ; bge a1,a0,+8
                #x6F #x00 #xC0 #x00     ; jal x0,+12
                #x13 #x05 #x15 #x00     ; addi a0,a0,1
                #x67 #x80 #x00 #x00     ; jalr x0,ra,0
                #x83 #x32 #x81 #x00))   ; ld t0,8(sp)
;; 数据里的地址字 = main 的绝对地址
(check-equal? (bytes-of-seg build 'd)
              '(0 0 #x10 0 0 0 0 0  #x68 #x69 0))

;; ---------------------------------------------------------------------------
;; 可选层: 不写 dce, 死块就留着
;; ---------------------------------------------------------------------------

(define with-dce
  (run-flow (list 'expand-pseudo 'analyze 'dce 'relax 'encode)
            (list (cons 'program-items src-dead) (cons 'data-items '())
                  (cons 'layout-spec spec-dead))))
(define without-dce
  (run-flow (list 'expand-pseudo 'analyze 'relax 'encode)
            (list (cons 'program-items src-dead) (cons 'data-items '())
                  (cons 'layout-spec spec-dead))))

;; 有 dce: 死块删掉, 只剩 main(addi) + end(jalr) = 8 字节
(check-equal? (length (bytes-of-seg (flow-value with-dce 'build) 'c)) 8)
;; 没有 dce: 死块留着 = 8 + 8 + 4 = 20 字节
(check-equal? (length (bytes-of-seg (flow-value without-dce 'build) 'c)) 20)

;; ---------------------------------------------------------------------------
;; 顺序可控: 伪指令必须在 analyze 之前展开(否则块边界和尺寸都不对)
;; ---------------------------------------------------------------------------

(define wrong-order
  (lambda ()
    (run-flow (list 'expand-pseudo 'flatten 'analyze 'dce 'relax 'encode)
              (list (cons 'program-items '((label main) (move a0 a1) (ret)))
                    (cons 'layout-spec '((segments (segment c code #x1000 #x1FFF 4))
                                         (place c (main))))))))

;; 正确顺序: expand-pseudo 在 analyze 之前
(define right-order
  (run-flow (list 'flatten 'expand-pseudo 'analyze 'dce 'relax 'encode)
            (list (cons 'program-items '((label main) (move a0 a1) (ret)))
                  (cons 'data-items '())
                  (cons 'layout-spec '((segments (segment c code #x1000 #x1FFF 4))
                                       (place c (main)))))))
(check-equal? (bytes-of-seg (flow-value right-order 'build) 'c)
              '(#x33 #x85 #x05 #x00  #x67 #x80 #x00 #x00))

;; 先 analyze 再 expand-pseudo: 伪指令没进 program, 最后编不出来
(check-exn exn:fail? wrong-order)

;; ---------------------------------------------------------------------------
;; 依赖检查 / 未知层
;; ---------------------------------------------------------------------------

;; encode 需要 layout, 前面没人产 -> 报错并指出谁能产
(check-exn #rx"能产出它的是: \\(layout relax\\)"
           (lambda () (run-flow (list 'encode) '())))

;; 未知层名 -> 报错并列出已知的层
(check-exn #rx"未知的层"
           (lambda () (run-flow (list 'no-such-stage) '())))

;; 缺外部输入也一样
(check-exn #rx"layout-spec"
           (lambda ()
             (run-flow (list 'analyze 'dce 'layout 'encode)
                       (list (cons 'program-items '()) (cons 'data-items '())))))

;; ---------------------------------------------------------------------------
;; 平层可以重复写, 也可以互换
;; ---------------------------------------------------------------------------

(check-equal? (run-flow (list 'flatten 'expand-pseudo 'analyze 'dce 'dce 'relax 'encode)
                        (list (cons 'program-items src) (cons 'data-items '())
                              (cons 'layout-spec spec-code)))
              (run-flow (list 'flatten 'expand-pseudo 'analyze 'dce 'relax 'encode)
                        (list (cons 'program-items src) (cons 'data-items '())
                              (cons 'layout-spec spec-code))))

;; layout 代替 relax: 这段程序不需要松弛, 结果一样
(check-equal? (bytes-of-seg
               (flow-value (run-flow (list 'flatten 'expand-pseudo 'analyze 'dce 'layout 'encode)
                                     (list (cons 'program-items src) (cons 'data-items '())
                                           (cons 'layout-spec spec-code)))
                           'build)
               'c)
              (bytes-of-seg build 'c))

(displayln "flow tests: ok")
