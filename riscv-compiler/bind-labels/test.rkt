#lang racket
;;; bind-labels/test.rkt -- anchors -> symbols, 最终宽度/容量检查

(require rackunit
         "bind.rkt"
         (only-in "../layout/layout.rkt"
                  layout-program layout-phase layout-problems layout-requests
                  layout-segments layout-anchors)
         (only-in "../target.rkt" target-rv64-base)
         (only-in "../analyze/analyze.rkt" analyze))

(define test-target target-rv64-base)
(define (layout-program* prog data spec)
  (layout-program test-target prog data spec))

(define (problems-of layout) (layout-problems layout))
(define (requests-of layout) (layout-requests layout))
(define (symbols-of layout) (layout-symbols layout))

(define (symbol-for layout chain)
  (findf (lambda (row) (equal? (cadr row) chain)) (symbols-of layout)))

;; ---------------------------------------------------------------------------
;; measured -> bound
;; ---------------------------------------------------------------------------

(define measured
  (layout-program*
   (analyze '((label main) (jalr x0 ra 0)
              (label f) (ret)))
   '((label d t) (value 8 (main)))
   '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4))
               (segment (name d) (kind data) (start #x8000) (end #x8FFF) (align 8)))
     (place c (main) (f)) (place d (d t)))))

(check-equal? (layout-phase measured) 'measured)
(check-false (assoc 'symbols measured))
(check-equal? (problems-of measured) '())
(check-equal? (requests-of measured) '())

(define bound (bind-labels measured))

(check-equal? (layout-phase bound) 'bound)
(check-true (bound-layout? bound))
(check-equal? (problems-of bound) '())
(check-equal? (requests-of bound) '())

;; 绝对地址 = 段 start + 偏移
(check-equal? (symbol-for bound '(main))
              '(symbol (main) c 0 #x1000))
(check-equal? (symbol-for bound '(f))
              '(symbol (f) c 4 #x1004))
(check-equal? (symbol-for bound '(d t))
              '(symbol (d t) d 0 #x8000))

;; anchors / segments 原样保留; bind 不改尺寸
(check-equal? (layout-anchors bound) (layout-anchors measured))
(check-equal? (layout-segments bound) (layout-segments measured))

;; 幂等
(check-equal? (bind-labels bound) bound)

;; symbol 查找 / 求值
(check-equal? (symbol-address (symbol-row (symbols-of bound) '(main))) #x1000)
(check-equal? (eval-symbol-address '(+ (main) 8) (symbols-of bound)) #x1008)
(check-equal? (eval-symbol-address '(- (f) (main)) (symbols-of bound)) 4)

;; ---------------------------------------------------------------------------
;; value 宽度: 只有最终地址才知道
;; ---------------------------------------------------------------------------

(define value-too-wide
  (layout-program*
   (analyze '((label main) (ret)))
   '((label d start) (fill 24 0)
     (label d end)
     (value 4 (- (d end) (d start)))       ; 差 24, 放得下
     (value 4 (d start)))                  ; 绝对地址 > 4GB, 放不下
   '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4))
               (segment (name d) (kind data) (start #x100000000) (end #x100001000) (align 8)))
     (place c (main)) (place d (d start) (d end)))))

;; measured 只查链; 宽度留给 bind-labels
(check-equal? (problems-of value-too-wide) '())
(check-equal? (problems-of (bind-labels value-too-wide))
              '((value-out-of-range d 28 (value 4 (d start)) #x100000000)))

;; 整数也兜底查: 即使 data-items 是直接 seed 进来的
(define integer-too-wide
  (layout-program*
   (analyze '((label main) (ret)))
   '((label d t) (value 4 #x100000000))
   '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4))
               (segment (name d) (kind data) (start #x8000) (end #x8FFF) (align 8)))
     (place c (main)) (place d (d t)))))

(check-equal? (problems-of integer-too-wide) '())
(check-equal? (problems-of (bind-labels integer-too-wide))
              '((value-out-of-range d 0 (value 4 #x100000000) #x100000000)))

;; 差值的两端都在 -> 用差值判宽度, 不看单个地址
(define diff-fits
  (layout-program*
   (analyze '((label main) (ret)))
   '((label d start) (fill 24 0)
     (label d end)
     (value 4 (- (d end) (d start))))
   '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4))
               (segment (name d) (kind data) (start #x100000000) (end #x100001000) (align 8)))
     (place c (main)) (place d (d start) (d end)))))

(check-equal? (problems-of (bind-labels diff-fits)) '())

;; ---------------------------------------------------------------------------
;; segment 容量: 最终尺寸才知道
;; ---------------------------------------------------------------------------

(define overflow
  (layout-program*
   (analyze '((label main) (addi a0 a0 1) (addi a0 a0 1)))
   '()
   '((segments (segment (name c) (kind code) (start #x1000) (end #x1007) (align 4)))
     (place c (main)))))

(check-equal? (problems-of overflow) '())
(check-equal? (problems-of (bind-labels overflow))
              '((segment-overflow c 8 7)))

;; ---------------------------------------------------------------------------
;; requests / problems 原样带过去
;; ---------------------------------------------------------------------------

(define with-requests
  (layout-program*
   (analyze '((label main) (branch-indirect beq a0 a1 (done))
              (label keep) (jal x0 (keep))
              (label done) (ret)))
   '()
   '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4)))
     (place c (main) (keep) (done)))))

(check-equal? (requests-of with-requests)
              '((scratch-hole c 0 (branch-indirect beq a0 a1 (done)) (code 0 0))))
(check-equal? (requests-of (bind-labels with-requests))
              (requests-of with-requests))

;; undefined-target 是 measured 的 problem; bind 不重复报, 也不崩
(define with-ghost
  (layout-program*
   (analyze '((label main) (jal x0 (ghost))))
   '()
   '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4)))
     (place c (main)))))

(check-equal? (problems-of (bind-labels with-ghost))
              '((undefined-target c 0 (jal x0 (ghost)))))

;; ---------------------------------------------------------------------------
;; 入口检查
;; ---------------------------------------------------------------------------

(check-exn #rx"需要 measured-layout"
           (lambda () (bind-labels '())))

(displayln "bind-labels tests: ok")
