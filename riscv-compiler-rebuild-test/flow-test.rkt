#lang racket
;;; flow-test.rkt -- 构建流: 层表 / 依赖 / 可选层 / 平层

(require rackunit
         "helpers.rkt"
         (rename-in "../riscv-compiler-rebuild/flow/flow.rkt"
                    [run-flow run-flow*] [run-stage run-stage*])
         (only-in "../riscv-compiler-rebuild/flow/flow.rkt" compile)
         (only-in "../riscv-compiler-rebuild/target.rkt" target-rv64-base))

(define test-target target-rv64-base)
(define (run-flow selector [seeds '()]) (run-flow* test-target selector seeds))
(define (run-stage name [seeds '()]) (run-stage* test-target name seeds))

;; ---------------------------------------------------------------------------
;; 层表
;; ---------------------------------------------------------------------------

(check-equal? (stage-names)
              '(analyze dce encode expand-data expand-pseudo flatten layout relax))

(check-equal? (providers-of 'data-items) '(expand-data flatten))
(check-equal? (providers-of 'program-items) '(expand-pseudo flatten))
(check-equal? (providers-of 'names) '(flatten))
(check-equal? (providers-of 'program) '(analyze dce))
(check-equal? (providers-of 'layout) '(layout relax))
(check-equal? (providers-of 'build) '(encode))
(check-equal? (providers-of 'nope) '())

(check-equal? (stage-requires (hash-ref stage-table 'analyze))
              '(program-items data-items))
(check-equal? (stage-provides (hash-ref stage-table 'analyze)) '(program))
(check-equal? (stage-requires (hash-ref stage-table 'encode)) '(layout))
(check-equal? (stage-provides (hash-ref stage-table 'encode)) '(build))

;; layout / relax 是平层: 同进同出
(check-equal? (stage-requires (hash-ref stage-table 'layout))
              (stage-requires (hash-ref stage-table 'relax)))
(check-equal? (stage-provides (hash-ref stage-table 'layout))
              (stage-provides (hash-ref stage-table 'relax)))

;; stage 自带说明
(for ([n (in-list (stage-names))])
  (check-true (string? (stage-doc (hash-ref stage-table n)))
              (format "doc for ~a" n)))

(check-equal? default-flow
              '(expand-data flatten expand-pseudo analyze dce relax encode))

;; ---------------------------------------------------------------------------
;; 简单跑一趟
;; ---------------------------------------------------------------------------

(define simple-src
  '((label main) (move a0 a1) (jalr x0 ra 0)))
(define simple-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16)))
    (place c (main))))

(define simple-seeds
  (list (cons 'rich-data '())
        (cons 'program-items simple-src)
        (cons 'layout-spec simple-spec)))

(define ctx (run-flow default-flow simple-seeds))
(check-true (hash-has-key? ctx 'data-items))

;; target 是 run-flow 的显式参数
(define targeted (run-flow* target-rv64-base default-flow simple-seeds))
(check-equal? (build-bytes (flow-value targeted 'build) 'c)
              (build-bytes (flow-value ctx 'build) 'c))
(check-true (hash-has-key? ctx 'program-items))
(check-true (hash-has-key? ctx 'names))
(check-true (hash-has-key? ctx 'program))
(check-true (hash-has-key? ctx 'layout))
(check-true (hash-has-key? ctx 'build))
(check-equal? (build-size (flow-value ctx 'build) 'c) 8)
(check-equal? (compile test-target simple-seeds) (flow-value ctx 'build))

;; 单独跑一层（层名可以直接写，不一定包成列表）
(check-equal? (flow-value (run-flow 'expand-data (list (cons 'rich-data '((b8 1)))))
                          'data-items)
              '((value 1 1)))
(check-equal? (flow-value (run-flow '(expand-data) (list (cons 'rich-data '((b8 1)))))
                          'data-items)
              '((value 1 1)))
(check-error "缺少 seed"
             (lambda () (run-flow 'expand-data '())))

;; ---------------------------------------------------------------------------
;; 选择器 / 层组 / 单层
;; ---------------------------------------------------------------------------

(check-equal? (group-names) '(all backend frontend ir))
(check-equal? (hash-ref stage-groups 'frontend)
              '(expand-data flatten expand-pseudo))
(check-equal? (hash-ref stage-groups 'ir) '(analyze dce))
(check-equal? (hash-ref stage-groups 'backend) '(relax encode))
(check-equal? (hash-ref stage-groups 'all) default-flow)

(check-equal? (select-stages 'analyze) '(analyze))
(check-equal? (select-stages 'frontend) '(expand-data flatten expand-pseudo))
(check-equal? (select-stages '(frontend ir backend)) default-flow)
(check-equal? (select-stages 'all) default-flow)
(check-equal? (select-stages '((expand-data flatten) (analyze dce)))
              '(expand-data flatten analyze dce))
(check-equal? (select-stages '()) '())

(check-error "未知层或组" (lambda () (select-stages 'no-such-stage)))
(check-error "选择器类型" (lambda () (select-stages "not-a-selector")))

;; 层组跑完整链，字节和 default-flow 一样
(define grouped (run-flow '(frontend ir backend) simple-seeds))
(check-equal? (build-bytes (flow-value grouped 'build) 'c)
              (build-bytes (flow-value ctx 'build) 'c))

;; 片段串联：前一段的 context 直接当下一段的 seed
(define front (run-flow 'frontend simple-seeds))
(check-true (hash-has-key? front 'program-items))
(check-true (hash-has-key? front 'data-items))
(define middle (run-flow 'ir front))
(check-true (hash-has-key? middle 'program))
(define back (run-flow 'backend middle))
(check-equal? (build-bytes (flow-value back 'build) 'c)
              (build-bytes (flow-value ctx 'build) 'c))

;; run-stage: 只跑一层，只返回这一层 provides 的值
(define expand-only
  (run-stage 'expand-data (list (cons 'rich-data '((b8 1))))))
(check-equal? (sort (hash-keys expand-only) symbol<?) '(data-items))
(check-equal? (hash-ref expand-only 'data-items) '((value 1 1)))

(define flatten-only
  (run-stage 'flatten
             (list (cons 'program-items '((module a (provide f) (label f))))
                   (cons 'data-items '()))))
(check-equal? (sort (hash-keys flatten-only) symbol<?)
              '(data-items names program-items))

(define analyze-only (run-stage 'analyze front))
(check-equal? (sort (hash-keys analyze-only) symbol<?) '(program))

(check-error "run-stage 只接受层名"
             (lambda () (run-stage 'frontend simple-seeds)))
(check-error "run-stage 未知层"
             (lambda () (run-stage 'no-such-stage '())))

;; ---------------------------------------------------------------------------
;; 依赖检查 / 未知层 / 顺序
;; ---------------------------------------------------------------------------

(check-error "analyze 缺 data-items"
             (lambda ()
               (run-flow '(analyze)
                         (list (cons 'program-items '((label main) (jalr x0 ra 0)))))))
(check-error "encode 缺 layout"
             (lambda () (run-flow '(encode) '())))
(check-error "未知层名"
             (lambda () (run-flow '(no-such-layer) '())))
;; 伪指令展开必须发生在 flatten 之后: expand-pseudo 不进入 module 壳
(define module-src
  '((module m (label main) (move a0 a1) (ret))))
(define module-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16)))
    (place c (m main))))
(define module-seeds
  (list (cons 'program-items module-src)
        (cons 'data-items '())
        (cons 'layout-spec module-spec)))
(define (wrong-pseudo-order)
  (run-flow '(expand-pseudo flatten analyze dce relax encode) module-seeds))
(define (right-pseudo-order)
  (run-flow '(flatten expand-pseudo analyze dce relax encode) module-seeds))
(check-error "expand-pseudo 在 flatten 之前: move 留在模块里"
             wrong-pseudo-order)
(check-equal? (build-bytes (flow-value (right-pseudo-order) 'build) 'c)
              '(#x33 #x85 #x05 #x00 #x67 #x80 #x00 #x00))

;; 同名层可以写两次; 后者覆盖前者, 但值相同
(check-equal? (flow-value (run-flow '(expand-data expand-data)
                                     (list (cons 'rich-data '((b8 1)))))
                          'data-items)
              '((value 1 1)))

;; ---------------------------------------------------------------------------
;; 可选层: 关掉 dce, 死块就留在产物里
;; ---------------------------------------------------------------------------

(define dead-src
  '((label main) (jal x0 (end))
    (label dead) (addi a1 a1 1) (jalr x0 ra 0)
    (label end) (jalr x0 ra 0)))

(define dead-spec-live
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16)))
    (place c (main) (end))))

(define dead-spec-all
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16)))
    (place c (main) (dead) (end))))

(define dead-seeds-live
  (list (cons 'rich-data '())
        (cons 'program-items dead-src)
        (cons 'layout-spec dead-spec-live)))

(define dead-seeds-all
  (list (cons 'rich-data '())
        (cons 'program-items dead-src)
        (cons 'layout-spec dead-spec-all)))

(define with-dce (run-flow default-flow dead-seeds-live))
(define without-dce (run-flow (remq 'dce default-flow) dead-seeds-all))

(check-equal? (build-size (flow-value with-dce 'build) 'c) 4)
(check-equal? (build-size (flow-value without-dce 'build) 'c) 16)

;; ---------------------------------------------------------------------------
;; 平层: layout 不松弛, relax 松弛; encode 对问题说 "不"
;; ---------------------------------------------------------------------------

(define far-src
  '((label main) (beq a0 a0 (far))
    (label hot) (jalr x0 ra 0)
    (label far) (jalr x0 ra 0)))

(define far-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
              (segment (name d) (kind code) (start #x2000) (end #x2100) (align 16)))
    (place c (main) (hot))
    (place d (far))))

(define far-seeds
  (list (cons 'rich-data '())
        (cons 'program-items far-src)
        (cons 'layout-spec far-spec)))

;; 只 layout: 留下 needs-far, encode 拒绝
(check-error "layout -> encode 有 needs-far"
             (lambda ()
               (run-flow '(expand-data flatten expand-pseudo analyze dce layout encode)
                         far-seeds)))

;; relax: 升成 branch-far, 能编码
(define relaxed (run-flow default-flow far-seeds))
(check-true (pair? (build-bytes (flow-value relaxed 'build) 'c)))

;; ---------------------------------------------------------------------------
;; flow-value
;; ---------------------------------------------------------------------------

(check-equal? (flow-value ctx 'names) (hash-ref ctx 'names))
(check-error "取不存在的值"
             (lambda () (flow-value ctx 'no-such-value)))

(finish-tests "flow")
