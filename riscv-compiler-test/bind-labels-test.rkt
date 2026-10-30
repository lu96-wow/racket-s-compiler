#lang racket
;;; bind-labels-test.rkt -- anchors -> symbols
;;;
;;; 锁住：
;;;   - measured 只有 anchors，没有 symbols
;;;   - bind-labels 后 phase=bound，地址 = 段 start + 偏移
;;;   - value 宽度 / segment 容量在 bind-labels 才检查
;;;   - requests 原样保留；bind 不改 item/size

(require rackunit
         "helpers.rkt"
         (rename-in "../riscv-compiler/layout/layout.rkt"
                    [layout-program layout-program*])
         (only-in "../riscv-compiler/bind-labels/bind.rkt"
                  bind-labels bound-layout? layout-symbols
                  symbol-row symbol-address eval-symbol-address)
         (only-in "../riscv-compiler/target.rkt" target-rv64-base)
         (only-in "../riscv-compiler/analyze/analyze.rkt" analyze))

(define test-target target-rv64-base)
(define (lay prog data spec) (layout-program* test-target prog data spec))

(define (symbol-for layout chain)
  (symbol-row (layout-symbols layout) chain))

(define (problems-of layout) (layout-problem-list layout))
(define (requests-of layout) (layout-request-list layout))

;; ---------------------------------------------------------------------------
;; anchors -> symbols
;; ---------------------------------------------------------------------------

(define measured
  (lay (analyze '((label main) (jalr x0 ra 0)
                  (label f) (ret)))
       '((label d t) (value 8 (main)))
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4))
                   (segment (name d) (kind data) (start #x8000) (end #x8FFF) (align 8)))
         (place c (main) (f)) (place d (d t)))))

(check-equal? (layout-phase-of measured) 'measured)
(check-false (assoc 'symbols measured))
(check-equal? (problems-of measured) '())
(check-equal? (requests-of measured) '())

(define bound (bind-labels measured))

(check-equal? (layout-phase-of bound) 'bound)
(check-true (bound-layout? bound))
(check-equal? (problems-of bound) '())
(check-equal? (requests-of bound) '())

(check-equal? (symbol-for bound '(main)) '(symbol (main) c 0 #x1000))
(check-equal? (symbol-for bound '(f)) '(symbol (f) c 4 #x1004))
(check-equal? (symbol-for bound '(d t)) '(symbol (d t) d 0 #x8000))
(check-equal? (symbol-address (symbol-for bound '(f))) #x1004)

;; anchors / segments 原样保留；bind 不改尺寸
(check-equal? (layout-anchor-list bound) (layout-anchor-list measured))
(check-equal? (cdr (assoc 'segments bound)) (cdr (assoc 'segments measured)))

;; 幂等
(check-equal? (bind-labels bound) bound)

;; 地址表达式求值
(check-equal? (eval-symbol-address '(+ (main) 8) (layout-symbols bound)) #x1008)
(check-equal? (eval-symbol-address '(- (f) (main)) (layout-symbols bound)) 4)
(check-error "未定义链"
             (lambda () (eval-symbol-address '(+ (nope) 1) (layout-symbols bound))))

;; ---------------------------------------------------------------------------
;; 最终宽度 / 容量检查
;; ---------------------------------------------------------------------------

;; measured 不查 value 宽度；bind-labels 才查
(define wide
  (lay (analyze '((label main) (ret)))
       '((label d t) (value 4 (d t)))
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4))
                   (segment (name d) (kind data) (start #x100000000) (end #x100001000) (align 8)))
         (place c (main)) (place d (d t)))))

(check-equal? (problems-of wide) '())
(check-true (has-problem? (bind-labels wide) 'value-out-of-range))

;; segment 容量也是最终尺寸才算
(define overflow
  (lay (analyze '((label main) (addi a0 a0 1) (addi a0 a0 1)))
       '()
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1007) (align 4)))
         (place c (main)))))

(check-equal? (problems-of overflow) '())
(check-true (has-problem? (bind-labels overflow) 'segment-overflow))

;; ---------------------------------------------------------------------------
;; requests / problems 原样带过去
;; ---------------------------------------------------------------------------

(define with-request
  (lay (analyze '((label main) (branch-indirect beq a0 a1 (done))
                  (label keep) (jal x0 (keep))
                  (label done) (ret)))
       '()
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4)))
         (place c (main) (keep) (done)))))

(check-true (has-request? with-request 'scratch-hole))
(check-equal? (requests-of (bind-labels with-request))
              (requests-of with-request))

(define with-ghost
  (lay (analyze '((label main) (jal x0 (ghost))))
       '()
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4)))
         (place c (main)))))

(check-equal? (problems-of (bind-labels with-ghost))
              (problems-of with-ghost))

;; ---------------------------------------------------------------------------
;; 入口检查
;; ---------------------------------------------------------------------------

(check-error "需要 measured-layout"
             (lambda () (bind-labels '())))

(finish-tests "bind-labels")
