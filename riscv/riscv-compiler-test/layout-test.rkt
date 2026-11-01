#lang racket
;;; layout-test.rkt -- 放置 / 度量 / 对齐 / 符号 / problems

(require rackunit
         "helpers.rkt"
         (rename-in "../riscv-compiler/layout/forms.rkt"
                    [item-size item-size*])
         (only-in "../riscv-compiler/layout/forms.rkt"
                  label-form? align-form? pad-form? bytes-form? fill-form?
                  value-form? compressed-form? value-width value-payload
                  la-form? la-scratch
                  jump-far-form? jump-far-link jump-far-scratch
                  item-kind
                  branch-form? jump-form? control-form? control-target
                  form-range scratch-hole?)
         (rename-in "../riscv-compiler/layout/layout.rkt"
                    [layout-program layout-program*])
         (only-in "../riscv-compiler/layout/layout.rkt"
                  layout-problems layout-anchors layout-phase layout-requests)
         (only-in "../riscv-compiler/target.rkt"
                  target-rv64-base target-rv32-all))

(define test-target target-rv64-base)
(define (item-size x) (item-size* test-target x))

(define (lay prog data spec) (layout-program* test-target prog data spec))

(define (one-block items)
  (program-of
   (list (list 'blocks (cons 'block (cons '((main)) items)))
         (list 'flows '(flow (succ) (fallthrough #f) (root? #t))))))

(define (plain-spec)
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16)))
    (place c (main))))

;; ---------------------------------------------------------------------------
;; forms: 尺寸 / 类别 / 区间 / 空槽
;; ---------------------------------------------------------------------------

(check-equal? (item-size '(label a)) 0)
(check-equal? (item-size '(align 8)) #f)
(check-equal? (item-size '(pad 5)) 5)
(check-equal? (item-size '(bytes 1 2 3)) 3)
(check-equal? (item-size '(bytes)) 0)
(check-equal? (item-size '(fill 4 0)) 4)
(check-equal? (item-size '(value 2 7)) 2)
(check-equal? (item-size '(c.addi a0 1)) 2)
(check-equal? (item-size '(c.beqz a0 L)) 2)
(check-equal? (item-size '(c.j L)) 2)
(check-equal? (item-size '(beq a b L)) 4)
(check-equal? (item-size '(jal x0 L)) 4)
(check-equal? (item-size '(jalr x0 ra 0)) 4)
(check-equal? (item-size '(branch-far beq a b L)) 8)
(check-equal? (item-size '(branch-indirect beq a b L)) 12)
(check-equal? (item-size '(jump-far ra L)) 8)
(check-equal? (item-size '(li a0 5)) 4)
(check-equal? (item-size '(li a0 2048)) 8)
(check-equal? (item-size '(li a0 #x80000000)) 12)
(check-equal? (item-size '(la a0 (x))) 8)

;; li 的尺寸跟着显式 target 的 XLEN 走
(check-equal? (item-size* target-rv64-base '(li a0 #x80000000)) 12)
(check-equal? (item-size* target-rv32-all '(li a0 #x80000000)) 4)
(check-error "rv32 放不下 64 位常量"
             (lambda () (item-size* target-rv32-all '(li a0 #x100000000))))

(check-equal? (item-kind '(label a)) 'marker)
(check-equal? (item-kind '(align 8)) 'align)
(check-equal? (item-kind '(pad 8)) 'pad)
(check-equal? (item-kind '(bytes 1)) 'materialized)
(check-equal? (item-kind '(fill 1 0)) 'materialized)
(check-equal? (item-kind '(value 1 0)) 'materialized)
(check-equal? (item-kind '(reserve 8)) 'space)
(check-equal? (item-size '(reserve 8)) 8)
(check-equal? (item-kind '(add a b c)) 'code)
(check-equal? (item-kind '(c.addi a0 1)) 'code)

(check-equal? (form-range '(beq a b L)) '(-4096 . 4094))
(check-equal? (form-range '(c.beqz a L)) '(-256 . 254))
(check-equal? (form-range '(c.j L)) '(-2048 . 2046))
(check-equal? (form-range '(jal x0 L)) '(-1048576 . 1048574))
(check-equal? (form-range '(branch-far beq a b L)) '(-1048572 . 1048578))
(check-false (form-range '(branch-indirect beq a b L)))
(check-false (form-range '(jump-far ra L)))
(check-false (form-range '(add a b c)))

;; scratch 空槽: 只看缺不缺那一项
(check-true  (scratch-hole? '(branch-indirect beq a b L)))
(check-false (scratch-hole? '(branch-indirect s beq a b L)))
(check-true  (scratch-hole? '(jump-far x0 L)))
(check-false (scratch-hole? '(jump-far ra L)))
(check-false (scratch-hole? '(jump-far ra s L)))
(check-false (scratch-hole? '(la a0 (x))))
(check-false (scratch-hole? '(add a b c)))

(check-equal? (la-scratch '(la a0 (x))) #f)
(check-equal? (la-scratch '(la a0 t0 (x))) 't0)
(check-equal? (jump-far-link '(jump-far x0 L)) 'x0)
(check-equal? (jump-far-scratch '(jump-far ra s L)) 's)
(check-equal? (jump-far-scratch '(jump-far ra L)) #f)

(check-true (compressed-form? '(c.addi a0 1)))
(check-false (compressed-form? '(add a b c)))
(check-true (control-form? '(beq a b L)))
(check-equal? (control-target '(beq a b (done))) '(done))

;; ---------------------------------------------------------------------------
;; 正常布局: 偏移 / 对齐 / 符号 / 空 problems
;; ---------------------------------------------------------------------------

(define prog
  (program-of
   '((blocks
      (block ((main))
             (addi a0 a0 1)
             (beq a0 a0 (done)))
      (block ((done)) (jalr x0 ra 0)))
     (flows
      (flow (succ 1) (fallthrough 1) (root? #t))
      (flow (succ) (fallthrough #f) (root? #f))))))

(define data
  '((label d tbl)
    (bytes 1 2 3)
    (align 8)
    (label d x)
    (value 4 7)))

(define spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
              (segment (name d) (kind data) (start #x2000) (end #x2100) (align 8)))
    (place c (main) (done))
    (place d (d tbl) (d x))))

(define laid (lay prog data spec))

(check-equal? (layout-phase-of laid) 'measured)
(check-equal? (layout-problem-list laid) '())
(check-equal? (layout-request-list laid) '())
(check-equal? (layout-item-forms laid 'c)
              '((label main) (addi a0 a0 1) (beq a0 a0 (done))
                (label done) (jalr x0 ra 0)))
(check-equal? (layout-size laid 'c) 12)

(check-equal? (layout-item-forms laid 'd)
              '((label d tbl) (bytes 1 2 3) (pad 5) (label d x) (value 4 7)))
(check-equal? (layout-items laid 'd)
              '((offset 0 (label d tbl))
                (offset 0 (bytes 1 2 3))
                (offset 3 (pad 5))
                (offset 8 (label d x))
                (offset 8 (value 4 7))))
(check-equal? (layout-size laid 'd) 12)

;; measured 只有 anchor: (anchor 链 段名 偏移), 没有绝对地址
(check-equal? (layout-anchors laid)
              '((anchor (main) c 0)
                (anchor (done) c 8)
                (anchor (d tbl) d 0)
                (anchor (d x) d 8)))
(check-false (assoc 'symbols laid))

;; 对齐看绝对地址: 段 start 不整除 align 也要补对
(define aligned
  (lay (one-block '((jalr x0 ra 0)))
       '((label d t) (align 8) (bytes 1))
       '((segments (segment (name c) (kind code) (start #x1003) (end #x1100) (align 1))
                   (segment (name d) (kind data) (start #x2003) (end #x2100) (align 1)))
         (place c (main))
         (place d (d t)))))
(check-equal? (layout-item-forms aligned 'd)
              '((label d t) (pad 5) (bytes 1)))
(check-equal? (layout-items aligned 'd)
              '((offset 0 (label d t))
                (offset 0 (pad 5))
                (offset 5 (bytes 1))))

;; ---------------------------------------------------------------------------
;; 段校验
;; ---------------------------------------------------------------------------

(define (problems-of prog data spec) (layout-problem-list (lay prog data spec)))

;; 只有 end < start 才是坏范围
(check-problem
 (lay (one-block '((jalr x0 ra 0))) '()
      '((segments (segment (name c) (kind code) (start 16) (end 8) (align 4)))
        (place c (main))))
 'segment-bad-range)

;; 空段合法(start == end): 还没有内容的 section 是常态, 不该逼上层丢 section
(define empty-data-laid
  (lay (one-block '((jalr x0 ra 0))) '()
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                   (segment (name d) (kind data) (start #x2000) (end #x2000) (align 8)))
         (place c (main)))))

(check-equal? (layout-problem-list empty-data-laid) '())
(check-equal? (layout-size empty-data-laid 'd) 0)
(check-equal? (layout-item-forms empty-data-laid 'd) '())

(check-problem
 (lay (one-block '((jalr x0 ra 0))) '()
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
                  (segment (name c) (kind code) (start #x2000) (end #x2100) (align 4)))
        (place c (main))))
 'segment-name-duplicated)

(check-problem
 (lay (one-block '((jalr x0 ra 0))) '()
      '((segments (segment (name c) (kind code) (start #x1002) (end #x1100) (align 4)))
        (place c (main))))
 'segment-misaligned)

(check-problem
 (lay (one-block '((jalr x0 ra 0))) '()
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
                  (segment (name d) (kind data) (start #x1080) (end #x1200) (align 4)))
        (place c (main))))
 'segment-overlap)

;; ---------------------------------------------------------------------------
;; hole 段: 有位置, 没有文件字节
;; ---------------------------------------------------------------------------
;; 归一化规则只有一个分叉: align 在 hole 段里变 reserve, 在 code/data 段里变 pad。
;; 好处是 hole 段的 items 永远只含 label / reserve, encode 不用再判"洞从哪儿开始"。

(define (hole-spec)
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
             (segment (name b) (kind hole) (start #x2000) (end #x2100) (align 8)))
    (place c (main))
    (place b (bss) (big) (bss-end))))

(define hole-laid
  (lay (one-block '((jalr x0 ra 0)))
       '((label bss) (reserve 8)
         (align 32) (label big) (reserve 16)
         (label bss-end))
       (hole-spec)))

(check-equal? (layout-problem-list hole-laid) '())

;; align(32) 在 0x2008 处要补 24 字节 —— 进产物是 (reserve 24), 不是 (pad 24)
(check-equal? (layout-item-forms hole-laid 'b)
              '((label bss) (reserve 8) (reserve 24)
                (label big) (reserve 16) (label bss-end)))
(check-equal? (layout-items hole-laid 'b)
              '((offset 0  (label bss))
                (offset 0  (reserve 8))
                (offset 8  (reserve 24))
                (offset 32 (label big))
                (offset 32 (reserve 16))
                (offset 48 (label bss-end))))
(check-equal? (layout-size hole-laid 'b) 48)

;; 不变量: hole 段里没有任何要写字节的 item
(check-equal? (for/list ([it (in-list (layout-item-forms hole-laid 'b))]
                         #:unless (label-form? it))
                       (car it))
              '(reserve reserve reserve))

;; 符号照样拿到位置(绝对地址由 bind-labels 绑)
(check-equal? (layout-anchor-list hole-laid)
              '((anchor (main) c 0)
                (anchor (bss) b 0) (anchor (big) b 32) (anchor (bss-end) b 48)))

;; 空 hole 是合法的: 一个地址也不占
(check-equal? (layout-problem-list
               (lay (one-block '((jalr x0 ra 0))) '()
                    '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                                (segment (name z) (kind hole) (start #x3000) (end #x3000) (align 16)))
                      (place c (main)))))
              '())
(check-equal? (layout-size (lay (one-block '((jalr x0 ra 0))) '()
                                '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                                            (segment (name z) (kind hole) (start #x3000) (end #x3000) (align 16)))
                                  (place c (main))))
                            'z)
              0)

;; hole 段不收要写字节的东西
(check-problem
 (lay (one-block '((jalr x0 ra 0)))
      '((label bss) (bytes 1 2))
      (hole-spec))
 'hole-materialized-item)

(check-problem
 (lay (one-block '((jalr x0 ra 0)))
      '((label bss) (pad 4))
      (hole-spec))
 'hole-materialized-item)

(check-problem
 (lay (one-block '((jalr x0 ra 0))) '()
      '((segments (segment (name b) (kind hole) (start #x2000) (end #x2100) (align 8)))
        (place b (main))))
 'hole-materialized-item)

;; reserve 只属于 hole 段
(check-problem
 (lay (one-block '((jalr x0 ra 0)))
      '((label d t) (reserve 8))
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                  (segment (name d) (kind data) (start #x2000) (end #x2100) (align 8)))
        (place c (main)) (place d (d t))))
 'reserve-outside-hole)

;; ---------------------------------------------------------------------------
;; 放置问题
;; ---------------------------------------------------------------------------

(check-problem
 (lay (one-block '((jalr x0 ra 0))) '()
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16)))))
 'unplaced-block)

(check-problem
 (lay (one-block '((jalr x0 ra 0))) '()
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16)))
        (place nope (main))))
 'unknown-segment)

(check-problem
 (lay (one-block '((jalr x0 ra 0))) '()
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16)))
        (place c (missing))))
 'unmatched-place)

(check-problem
 (lay (one-block '((jalr x0 ra 0))) '()
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                  (segment (name d) (kind code) (start #x2000) (end #x2100) (align 16)))
        (place c (main))
        (place d (main))))
 'ambiguous-placement)

(check-problem
 (lay (one-block '((jalr x0 ra 0)))
      '((label d t) (bytes 1))
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                  (segment (name d) (kind data) (start #x2000) (end #x2100) (align 16)))
        (place c (main))))
 'unplaced)

(check-problem
 (lay (one-block '((jalr x0 ra 0)))
      '((bytes 1 2))
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16)))
        (place c (main))))
 'unlabeled-run)

(check-problem
 (lay (one-block '((jalr x0 ra 0)))
      '((label d t) (bytes 1))
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16)))
        (place c (main) (d t))))
 'code-data-mixed)

(check-problem
 (lay (one-block '((jalr x0 ra 0))) '()
      '((segments (segment (name d) (kind data) (start #x1000) (end #x1100) (align 16)))
        (place d (main))))
 'data-code-mixed)

;; 顺序后继被段剪断
(define p-broken
  (program-of
   '((blocks (block ((main)) (addi a0 a0 1) (beq a0 a0 (next)))
             (block ((next)) (jalr x0 ra 0)))
     (flows (flow (succ 1) (fallthrough 1) (root? #t))
            (flow (succ) (fallthrough #f) (root? #f))))))
(check-problem
 (lay p-broken '()
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                  (segment (name d) (kind code) (start #x2000) (end #x2100) (align 16)))
        (place c (main))
        (place d (next))))
 'broken-fallthrough)

;; ---------------------------------------------------------------------------
;; 符号 / 范围
;; ---------------------------------------------------------------------------

;; 目标不存在
(check-problem
 (lay (one-block '((beq a0 a0 (nope)))) '() (plain-spec))
 'undefined-target)

;; 够不着的普通分支: 交给 relax
(check-request
 (lay (program-of
       '((blocks (block ((main)) (beq a0 a0 (far)))
                 (block ((far)) (jalr x0 ra 0)))
         (flows (flow (succ 1) (fallthrough #f) (root? #t))
                (flow (succ) (fallthrough #f) (root? #f)))))
      '()
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                  (segment (name d) (kind code) (start #x200000) (end #x201000) (align 16)))
        (place c (main))
        (place d (far))))
 'needs-far)

;; scratch 空槽: 报 problem, 不抛异常
(check-request
 (lay (one-block '((branch-indirect beq a0 a1 (main)))) '() (plain-spec))
 'scratch-hole)
(check-request
 (lay (one-block '((jump-far x0 (main)))) '() (plain-spec))
 'scratch-hole)

;; 地址字里的链不存在
(check-problem
 (lay (one-block '((jalr x0 ra 0)))
      '((label d t) (value 4 (nope)))
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                  (segment (name d) (kind data) (start #x2000) (end #x2100) (align 16)))
        (place c (main))
        (place d (d t))))
 'undefined-target)

;; 近形式 la 够不着
(check-request
 (lay (program-of
       '((blocks (block ((main)) (la t0 (far)) (jalr x0 ra 0))
                 (block ((far)) (jalr x0 ra 0)))
         (flows (flow (succ) (fallthrough #f) (root? #t))
                (flow (succ) (fallthrough #f) (root? #f)))))
      '()
      '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                  (segment (name d) (kind code) (start #x90000000) (end #x90001000) (align 16)))
        (place c (main))
        (place d (far))))
 'la-too-far)

;; li 的尺寸是精确值, 不是上界; 段容量按精确尺寸算
(check-equal? (layout-size
               (lay (one-block '((li a0 5)))
                    '()
                    '((segments (segment (name c) (kind code)
                                         (start #x1000) (end #x1004) (align 4)))
                      (place c (main))))
               'c)
              4)
(check-equal? (layout-size
               (lay (one-block '((li a0 2048)))
                    '()
                    '((segments (segment (name c) (kind code)
                                         (start #x1000) (end #x1008) (align 4)))
                      (place c (main))))
               'c)
              8)

(finish-tests "layout")
