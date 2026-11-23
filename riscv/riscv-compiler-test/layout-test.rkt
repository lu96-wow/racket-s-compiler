#lang racket
;;; layout-test.rkt -- 放置 / 度量 / 对齐 / 符号 / problems

(require rackunit
         "helpers.rkt"
         (rename-in "../riscv-compiler/layout/forms.rkt"
                    [item-size item-size*])
         (only-in "../riscv-compiler/layout/forms.rkt"
                  label-form? align-form? pad-form? bytes-form? fill-form?
                  value-form? compressed-form? value-width value-payload
                  la-pcrel-form?
                  la-pcrel-li-add-form? la-pcrel-li-add-tmp
                  branch-auipc-jalr-scratch
                  jump-auipc-jalr-link jump-auipc-jalr-base
                  item-kind
                  branch-form? jump-form? control-form? control-target
                  form-range)
         (rename-in "../riscv-compiler/layout/layout.rkt"
                    [layout-program layout-program*])
         (only-in "../riscv-compiler/layout/layout.rkt"
                  layout-problems layout-anchors layout-phase)
         (only-in "../riscv-compiler/check/check.rkt" check-layout)
         (only-in "../riscv-compiler/target.rkt"
                  target-rv64-base target-rv32-all)
         (only-in "../riscv-compiler/code.rkt" sexp->code))

(define test-target target-rv64-base)
(define (item-size x) (item-size* test-target x))

(define (lay prog data spec) (layout-program* test-target prog data spec))
(define (check-lay prog data spec)
  (check-layout test-target (lay prog data spec)))

(define (code-of-blocks blocks falls)
  (sexp->code (list (cons 'blocks blocks) (cons 'falls falls))))

(define (one-block items)
  (code-of-blocks
   (list (cons 'block (cons '((main)) items)))
   '()))

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
(check-equal? (item-size '(branch-jal beq a b L)) 8)
(check-equal? (item-size '(branch-auipc-jalr s beq a b L)) 12)
(check-equal? (item-size '(jump-auipc-jalr ra ra L)) 8)
(check-equal? (item-size '(li a0 5)) 4)
(check-equal? (item-size '(li a0 2048)) 8)
(check-equal? (item-size '(li a0 #x80000000)) 12)
(check-equal? (item-size '(la-pcrel a0 (x))) 8)
(check-equal? (item-size '(la-pcrel-li-add a0 t0 (x))) 40)

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
(check-equal? (form-range '(branch-jal beq a b L)) '(-1048572 . 1048578))
(check-false (form-range '(branch-auipc-jalr s beq a b L)))
(check-false (form-range '(jump-auipc-jalr ra ra L)))
(check-false (form-range '(add a b c)))

;; 形式形状 / 必需操作数
(check-true  (la-pcrel-form? '(la-pcrel a0 (x))))
(check-false (la-pcrel-form? '(la-pcrel a0 t0 (x))))
(check-true  (la-pcrel-li-add-form? '(la-pcrel-li-add a0 t0 (x))))
(check-false (la-pcrel-li-add-form? '(la-pcrel-li-add a0 (x))))
(check-equal? (la-pcrel-li-add-tmp '(la-pcrel-li-add a0 t0 (x))) 't0)

(check-equal? (branch-auipc-jalr-scratch '(branch-auipc-jalr s beq a b L)) 's)
(check-equal? (jump-auipc-jalr-link '(jump-auipc-jalr ra ra L)) 'ra)
(check-equal? (jump-auipc-jalr-base '(jump-auipc-jalr x0 t0 L)) 't0)

(check-true (compressed-form? '(c.addi a0 1)))
(check-false (compressed-form? '(add a b c)))
(check-true (control-form? '(beq a b L)))
(check-equal? (control-target '(beq (done) a b)) '(done))

;; ---------------------------------------------------------------------------
;; 正常布局: 偏移 / 对齐 / 符号 / 空 problems
;; ---------------------------------------------------------------------------

(define prog
  (code-of-blocks
   '((block ((main))
            (addi a0 a0 1)
            (beq (done) a0 a0))
     (block ((done)) (jalr x0 ra 0)))
   '((fall 0 1))))

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
(check-equal? (layout-item-forms laid 'c)
              '((label main) (addi a0 a0 1) (beq (done) a0 a0)
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

;; 地址求解: 段不给 (start …) 时由 layout 按 (align …) 递增, 游标从 (origin …) 起步
(define auto-laid
  (lay (one-block '((jalr x0 ra 0)))
       '((label d t) (value 8 1))
       '((origin #x400000)
         (segments (segment (name c) (kind code) (size 16) (align 4096))
                   (segment (name d) (kind data) (size 8) (align 4096)))
         (place c (main))
         (place d (d t)))))

(check-equal? (layout-problem-list auto-laid) '())
(check-equal? (layout-anchor-list auto-laid)
              '((anchor (main) c 0) (anchor (d t) d 0)))
(check-equal? (for/list ([seg (in-list (cdr (assq 'segments auto-laid)))])
                       (cadr (assq 'start (cdr seg))))
              (list #x400000 #x401000))
;; (end …) 和 (size …) 等价: size 变成 end = start + size
(check-equal? (for/list ([seg (in-list (cdr (assq 'segments auto-laid)))])
                       (cadr (assq 'end (cdr seg))))
              (list #x400010 #x401008))
;; 两者都不给: 容量无从校验, 直接报错
(check-error "段声明缺容量" (lambda () (lay (one-block '((jalr x0 ra 0))) '()
                                        '((segments (segment (name c) (kind code) (align 4)))
                                          (place c (main))))))

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
  (code-of-blocks
   '((block ((main)) (addi a0 a0 1) (beq (next) a0 a0))
     (block ((next)) (jalr x0 ra 0)))
   '((fall 0 1))))
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
 (check-lay (one-block '((beq (nope) a0 a0))) '() (plain-spec))
 'undefined-target)

;; 够不着的普通分支: check 报 problem, 不自动升级
(check-problem
 (check-lay (code-of-blocks
             '((block ((main)) (beq (far) a0 a0))
               (block ((far)) (jalr x0 ra 0)))
             '())
            '()
            '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                        (segment (name d) (kind code) (start #x200000) (end #x201000) (align 16)))
              (place c (main))
              (place d (far))))
 'out-of-range)

;; scratch 空槽: check 报 problem, 不抛异常
(check-problem
 (check-lay (one-block '((branch-auipc-jalr x0 beq a0 a1 (main)))) '() (plain-spec))
 'zero-scratch)
(check-problem
 (check-lay (one-block '((jump-auipc-jalr x0 x0 (main)))) '() (plain-spec))
 'zero-scratch)

;; 地址字里的链不存在
(check-problem
 (check-lay (one-block '((jalr x0 ra 0)))
            '((label d t) (value 4 (nope)))
            '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                        (segment (name d) (kind data) (start #x2000) (end #x2100) (align 16)))
              (place c (main))
              (place d (d t))))
 'undefined-target)

;; 近形式 la 够不着
(check-problem
 (check-lay (code-of-blocks
             '((block ((main)) (la-pcrel t0 (far)) (jalr x0 ra 0))
               (block ((far)) (jalr x0 ra 0)))
             '())
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
