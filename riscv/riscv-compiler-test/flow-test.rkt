#lang racket
;;; flow-test.rkt -- 构建流: 层表 / 依赖 / 层组 / 选择器

(require rackunit
         "helpers.rkt"
         (rename-in "../riscv-compiler/flow/flow.rkt"
                    [run-flow run-flow*] [run-stage run-stage*])
         (only-in "../riscv-compiler/flow/flow.rkt" compile)
         (only-in "../riscv-compiler/target.rkt" target-rv64-base))

(define test-target target-rv64-base)
(define (run-flow selector [seeds '()]) (run-flow* test-target selector seeds))
(define (run-stage name [seeds '()]) (run-stage* test-target name seeds))

;; ---------------------------------------------------------------------------
;; 层表
;; ---------------------------------------------------------------------------

(check-equal? (stage-names)
              '(bind-labels check emit-program emit-unit encode expand-data
                            expand-struct flatten layout load-units lower-code validate))

(check-equal? (providers-of 'data-items) '(expand-data flatten))
(check-equal? (providers-of 'program-items) '(expand-struct flatten))
(check-equal? (providers-of 'names) '(flatten))
(check-equal? (providers-of 'program) '(emit-program))
(check-equal? (providers-of 'code) '(lower-code validate))
(check-equal? (providers-of 'measured-layout) '(check layout))
(check-equal? (providers-of 'bound-layout) '(bind-labels))
(check-equal? (providers-of 'structs) '(expand-struct))
(check-equal? (providers-of 'unit) '(emit-unit))
(check-equal? (providers-of 'build) '(encode))
(check-equal? (providers-of 'nope) '())

(check-equal? (stage-requires (hash-ref stage-table 'validate)) '(code))
(check-equal? (stage-provides (hash-ref stage-table 'validate)) '(code))
(check-equal? (stage-requires (hash-ref stage-table 'encode))
              '(bound-layout
                (optional structs)
                (optional label-provides)
                (optional struct-provides)
                (optional unit)))
(check-equal? (stage-provides (hash-ref stage-table 'encode)) '(build))

;; stage 自带说明
(for ([n (in-list (stage-names))])
  (check-true (string? (stage-doc (hash-ref stage-table n)))
              (format "doc for ~a" n)))

(check-equal? default-flow
              '(load-units expand-struct expand-data flatten lower-code validate emit-unit
                layout check bind-labels encode emit-program))

;; ---------------------------------------------------------------------------
;; 简单跑一趟
;; ---------------------------------------------------------------------------

(define simple-src
  '((label main) (mv a0 a1) (jalr x0 ra 0)))
(define simple-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16)))
    (place c (main))))

(define (seeds src [spec simple-spec] [rich '()])
  (list (cons 'code (code-of src))
        (cons 'rich-data rich)
        (cons 'program-items src)
        (cons 'layout-spec spec)))

(define simple-seeds (seeds simple-src))

(define ctx (run-flow default-flow simple-seeds))
(check-true (hash-has-key? ctx 'data-items))

;; code 也可以直接当 seed：后端不要求 program-items
(define code-only
  (run-flow '(lower-code validate emit-unit layout check bind-labels encode)
            (list (cons 'code (code-of simple-src))
                  (cons 'data-items '())
                  (cons 'layout-spec simple-spec))))
(check-equal? (build-size (flow-value code-only 'build) 'c) 8)

;; target 是 run-flow 的显式参数
(define targeted (run-flow* target-rv64-base default-flow simple-seeds))
(check-equal? (build-bytes (flow-value targeted 'build) 'c)
              (build-bytes (flow-value ctx 'build) 'c))
(check-true (hash-has-key? ctx 'program-items))
(check-true (hash-has-key? ctx 'names))
(check-true (hash-has-key? ctx 'code))
(check-true (hash-has-key? ctx 'program))
(check-true (hash-has-key? ctx 'measured-layout))
(check-true (hash-has-key? ctx 'bound-layout))
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

;; validate 只检查，不改 code
(check-equal? (flow-value (run-stage 'validate (list (cons 'code (code-of simple-src)))) 'code)
              (code-of simple-src))
(check-error "validate 拒绝省略 link 的 jal"
             (lambda ()
               (run-stage 'validate
                          (list (cons 'code (code-of '((label g) (jal g))))))))

;; ---------------------------------------------------------------------------
;; 选择器 / 层组 / 单层
;; ---------------------------------------------------------------------------

(check-equal? (group-names) '(all backend frontend))
(check-equal? (hash-ref stage-groups 'frontend)
              '(load-units expand-struct expand-data flatten lower-code))
(check-equal? (hash-ref stage-groups 'backend)
              '(validate emit-unit layout check bind-labels encode emit-program))
(check-equal? (hash-ref stage-groups 'all) default-flow)

(check-equal? (select-stages 'validate) '(validate))
(check-equal? (select-stages 'frontend) '(load-units expand-struct expand-data flatten lower-code))
(check-equal? (select-stages '(frontend backend)) default-flow)
(check-equal? (select-stages 'all) default-flow)
(check-equal? (select-stages '((expand-data flatten) (lower-code validate)))
              '(expand-data flatten lower-code validate))
(check-equal? (select-stages '()) '())

(check-error "未知层或组" (lambda () (select-stages 'no-such-stage)))
(check-error "选择器类型" (lambda () (select-stages "not-a-selector")))

;; 层组跑完整链，字节和 default-flow 一样
(define grouped (run-flow '(frontend backend) simple-seeds))
(check-equal? (build-bytes (flow-value grouped 'build) 'c)
              (build-bytes (flow-value ctx 'build) 'c))

;; 片段串联：前一段的 context 直接当下一段的 seed
(define front (run-flow 'frontend simple-seeds))
(check-true (hash-has-key? front 'program-items))
(check-true (hash-has-key? front 'data-items))
(check-true (hash-has-key? front 'code))
(define back (run-flow 'backend front))
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
              '(data-items exports label-provides module-requires names program-items))

(check-equal? (sort (hash-keys (run-stage 'validate front)) symbol<?) '(code))

(check-error "run-stage 只接受层名"
             (lambda () (run-stage 'frontend simple-seeds)))
(check-error "run-stage 未知层"
             (lambda () (run-stage 'no-such-stage '())))

;; ---------------------------------------------------------------------------
;; 依赖检查 / 未知层 / 顺序
;; ---------------------------------------------------------------------------

(check-error "validate 缺 code"
             (lambda () (run-flow '(validate) '())))
(check-error "encode 缺 layout"
             (lambda () (run-flow '(encode) '())))
(check-error "未知层名"
             (lambda () (run-flow '(no-such-layer) '())))
;; 同名层可以写两次; 后者覆盖前者, 但值相同
(check-equal? (flow-value (run-flow '(expand-data expand-data)
                                     (list (cons 'rich-data '((b8 1)))))
                          'data-items)
              '((value 1 1)))

;; ---------------------------------------------------------------------------
;; check: 短形式超范围拒绝; 显式远形式通过; 不存在自动升级
;; ---------------------------------------------------------------------------

(define far-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
              (segment (name d) (kind code) (start #x80000) (end #x801000) (align 16)))
    (place c (main) (hot))
    (place d (far))))

(define (far-seeds src)
  (seeds src far-spec))

;; 普通 short form: check 报 out-of-range, encode 拒绝
(check-error "短形式超范围, 不自动升级"
             (lambda ()
               (run-flow default-flow
                         (far-seeds '((label main) (beq (far) a0 a0)
                                      (label hot) (jalr x0 ra 0)
                                      (label far) (jalr x0 ra 0))))))

;; 显式远形式: 能编码
(define explicit-far
  (run-flow default-flow
            (far-seeds '((label main) (branch-jal beq a0 a0 (far))
                         (label hot) (jalr x0 ra 0)
                         (label far) (jalr x0 ra 0)))))
(check-equal? (build-size (flow-value explicit-far 'build) 'c) 12)

;; ---------------------------------------------------------------------------
;; flow-value
;; ---------------------------------------------------------------------------

(check-equal? (flow-value ctx 'names) (hash-ref ctx 'names))
(check-error "取不存在的值"
             (lambda () (flow-value ctx 'no-such-value)))

(finish-tests "flow")
