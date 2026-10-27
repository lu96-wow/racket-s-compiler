#lang racket
;;; L5/test.rkt
;;; L5 吃 L3/L4 的块列表: 放置以块为单位, place 行精确匹配 label 链,
;;; 放完检查 fallthrough 是否被剪断。

(require rackunit
         "forms.rkt"
         "layout.rkt"
         (only-in "../D1/expand.rkt" expand-data)
         (only-in "../L1/flatten.rkt" flatten-inputs)
         (only-in "../L2/rewrite.rkt" rewrite-program)
         (only-in "../L3/analyze.rkt" analyze)
         (only-in "../L4/dce.rkt" eliminate-dead))

;; ---------------------------------------------------------------------------
;; 形式表
;; ---------------------------------------------------------------------------

(check-equal? (item-size '(bge a b (l))) 4)
(check-equal? (item-size '(branch-far beq a b (l))) 8)
(check-equal? (item-size '(branch-indirect beq a b (l))) 12)
(check-equal? (item-size '(branch-indirect t0 beq a b (l))) 12)
(check-equal? (item-size '(jal x0 (l))) 4)
(check-equal? (item-size '(jump-far x0 (l))) 8)
(check-equal? (item-size '(jump-far x0 t0 (l))) 8)
(check-equal? (item-size '(jump-far ra (l))) 8)
;; call-far 已删: 它就是 (jump-far ra L)
(check-false (jump-form? '(call-far (l))))
(check-equal? (item-size '(la t0 (l))) 8)
(check-equal? (item-size '(la t0 tmp (l))) 8)
(check-equal? (item-size '(label l)) 0)
(check-equal? (item-size '(bytes 1 2 3)) 3)
(check-equal? (item-size '(fill 4096 0)) 4096)
(check-equal? (item-size '(value 8 (label+ (d t) 0))) 8)
(check-equal? (item-size '(value 4 7)) 4)
(check-true  (value-form? '(value 2 258)))
(check-true  (value-form? '(value 8 (label+ (d t) 0))))
(check-false (value-form? '(value 3 0)))              ; 宽度只认 1/2/4/8
(check-false (value-form? '(value 8)))                ; 少了值
(check-true  (label-expr? '(label+ (d t) 0)))
(check-false (label-expr? '(label+ (d t))))           ; 核心形式里加数必须写
(check-equal? (label-expr-chain '(label+ (d t) 8)) '(d t))
(check-equal? (label-expr-addend '(label+ (d t) -8)) -8)
(check-true  (fill-form? '(fill 4096 0)))
(check-false (fill-form? '(fill 4096 256)))
(check-false (fill-form? '(fill 4096)))
(check-equal? (item-size '(addi a0 a0 1)) 4)
(check-equal? (item-size '(c.addi a0 1)) 2)

;; 可达距离是区间, 不是幅度: 偶数偏移下 [+2^n-2 .. -2^n]
(check-equal? (form-range '(bge a b (l))) '(-4096 . 4094))
(check-equal? (form-range '(branch-far beq a b (l))) '(-1048572 . 1048578))
(check-false  (form-range '(branch-indirect beq a b (l))))
(check-equal? (form-range '(jal x0 (l))) '(-1048576 . 1048574))
(check-false  (form-range '(jump-far x0 (l))))
(check-false  (form-range '(jump-far ra (l))))
(check-false  (form-range '(addi a0 a0 1)))

;; 远形式带条件字段
(check-equal? (item-size '(branch-far beq a b (l))) 8)
(check-equal? (item-size '(branch-indirect beq a b (l))) 12)
(check-equal? (control-target '(branch-far beq a b (l))) '(l))
(check-true  (branch-form? '(branch-far beq a b (l))))
(check-true  (branch-form? '(branch-indirect t0 beq a b (l))))

(check-true  (scratch-hole? '(branch-indirect beq a b (l))))
(check-false (scratch-hole? '(branch-indirect t0 beq a b (l))))
;; jump-far 要不要 scratch 是 link 的函数, 不是"少一项"的函数
(check-true  (scratch-hole? '(jump-far x0 (l))))
(check-true  (scratch-hole? '(jump-far zero (l))))
(check-true  (scratch-hole? '(jump-far 0 (l))))
(check-false (scratch-hole? '(jump-far ra (l))))       ; link 自己就是 base
(check-false (scratch-hole? '(jump-far x0 t0 (l))))
(check-false (scratch-hole? '(jump-far ra t0 (l))))
(check-equal? (jump-far-link '(jump-far ra t0 (l))) 'ra)
(check-equal? (jump-far-scratch '(jump-far x0 t0 (l))) 't0)
(check-false (jump-far-scratch '(jump-far ra (l))))
(check-true  (jump-far-form? '(jump-far x0 (l))))
(check-false (jump-far-form? '(jump-far)))
(check-false (jump-far-form? '(jump-far x0 t0 t1 (l))))
(check-false (scratch-hole? '(bge a b (l))))

;; la 的 scratch 是可选槽, 不是空槽: 缺省不是缺陷, 不要求 L6 填
(check-true  (la-form? '(la t0 (l))))
(check-true  (la-form? '(la t0 tmp (l))))
(check-true  (la-form? '(la t0 (a b))))
(check-true  (la-form? '(la t0 l)))
(check-false (la-form? '(la t0)))
(check-true  (la-form? '(la t0 tmp)))      ; 3 项时最后一项就是链(裸原子)
(check-false (la-scratch '(la t0 (l))))
(check-equal? (la-scratch '(la t0 tmp (l))) 'tmp)
(check-false (scratch-hole? '(la t0 (l))))

(check-equal? (item-kind '(label a)) 'marker)
(check-equal? (item-kind '(align 8)) 'both)
(check-equal? (item-kind '(bytes 1)) 'data)
(check-equal? (item-kind '(fill 4 0)) 'data)
(check-equal? (item-kind '(value 8 (label+ (d t) 0))) 'data)
(check-equal? (item-kind '(addi a0 a0 1)) 'code)

;; 压缩形式: 2 字节; 控制转移按 C 扩展的范围
(check-true  (compressed-form? '(c.addi a0 1)))
(check-true  (compressed-form? '(c.j (l))))
(check-false (compressed-form? '(addi a0 a0 1)))
(check-equal? (item-size '(c.nop)) 2)
(check-equal? (item-size '(c.addi a0 1)) 2)
(check-equal? (item-size '(c.j (l))) 2)
(check-equal? (item-size '(c.jal (l))) 2)
(check-equal? (item-size '(c.beqz a (l))) 2)
(check-equal? (item-kind '(c.addi a0 1)) 'code)
(check-equal? (form-range '(c.j (l))) '(-2048 . 2046))
(check-equal? (form-range '(c.jal (l))) '(-2048 . 2046))
(check-equal? (form-range '(c.beqz a (l))) '(-256 . 254))
(check-equal? (form-range '(c.bnez a (l))) '(-256 . 254))
(check-false  (form-range '(c.addi a0 1)))

;; ---------------------------------------------------------------------------
;; 小工具: 程序 -> L3 块 -> L4 布局
;; ---------------------------------------------------------------------------

(define (lay prog data layout)
  (layout-program (eliminate-dead (analyze prog)) data layout))

;; 只跑 L3 + L5: 不让 L4 把"跳到紧邻下一块"的转移删掉, 才能看见 scratch 空槽
(define (lay0 prog data layout)
  (layout-program (analyze prog) data layout))

(define (segments-of layout) (cdr (assoc 'segments layout)))
(define (seg-of layout name)
  (findf (lambda (s) (equal? (cadr (assoc 'name (cdr s))) name)) (segments-of layout)))
(define (items-of-seg layout name) (cdr (assoc 'items (cdr (seg-of layout name)))))
(define (size-of-seg layout name) (cadr (assoc 'size (cdr (seg-of layout name)))))
(define (symbols-of layout) (cdr (assoc 'symbols layout)))
(define (problems-of layout) (cdr (assoc 'problems layout)))

;; ---------------------------------------------------------------------------
;; 一个段: 按块顺序摆放, 累加字节
;; ---------------------------------------------------------------------------

(define l1 (lay '((label main) (addi a0 a0 1) (bge a0 a1 (c))
                  (label b) (addi a1 a1 1)
                  (label c) (addi a2 a2 1))
                '()
                '((segments (segment prog1 code #x100000 #x100FFF 16))
                  (place prog1 (main) (b) (c)))))

(check-equal? (map car l1) '(segments symbols problems))   ; 顶层是字段表, 无标签
(check-equal? (items-of-seg l1 'prog1)
              '((offset 0 (label main)) (offset 0 (addi a0 a0 1)) (offset 4 (bge a0 a1 (c)))
                (offset 8 (label b)) (offset 8 (addi a1 a1 1))
                (offset 12 (label c)) (offset 12 (addi a2 a2 1))))
(check-equal? (size-of-seg l1 'prog1) 16)
(check-equal? (problems-of l1) '())

(check-equal? (findf (lambda (s) (equal? (car s) '(main))) (symbols-of l1))
              '((main) prog1 0 #x100000))
(check-equal? (findf (lambda (s) (equal? (car s) '(b))) (symbols-of l1))
              '((b) prog1 8 #x100008))
(check-equal? (findf (lambda (s) (equal? (car s) '(c))) (symbols-of l1))
              '((c) prog1 12 #x10000c))

;; 压缩分支/跳转: 同理占 2 字节, 目标照查
;; (目标故意不指向物理下一块, 否则会被 L4 当冗余转移删掉)
(define lc (lay '((label a) (c.beqz t0 (c))
                  (label b) (c.j (d))
                  (label c) (c.addi a0 1)
                  (label d) (c.addi a1 1))
                '()
                '((segments (segment s1 code #x100000 #x1000FF 4))
                  (place s1 (a) (b) (c) (d)))))
(check-equal? (items-of-seg lc 's1)
              '((offset 0 (label a)) (offset 0 (c.beqz t0 (c)))
                (offset 2 (label b)) (offset 2 (c.j (d)))
                (offset 4 (label c)) (offset 4 (c.addi a0 1))
                (offset 6 (label d)) (offset 6 (c.addi a1 1))))
(check-equal? (size-of-seg lc 's1) 8)
(check-equal? (problems-of lc) '())

;; 压缩跳转超出 ±2 KiB -> needs-far (c.jal 会落下, 中间块可达)
(check-equal? (problems-of
               (lay '((label a) (c.jal (far))
                      (label mid) (align 4096) (addi a0 a0 1)
                      (label far) (addi a1 a1 1))
                    '()
                    '((segments (segment s1 code #x100000 #x101FFF 4096))
                      (place s1 (a) (mid) (far)))))
              '((needs-far s1 0 (c.jal (far)) 4100 (code 0 0))))

;; 压缩分支目标不存在 -> undefined-target
(check-equal? (problems-of
               (lay '((label a) (c.beqz t0 (ghost)) (label b) (addi a0 a0 1))
                    '()
                    '((segments (segment s1 code #x100000 #x1000FF 4))
                      (place s1 (a) (b)))))
              '((undefined-target s1 0 (c.beqz t0 (ghost)))))

;; ---------------------------------------------------------------------------
;; 两个段: 中间用 jal x0 断开, 没有 fallthrough
;; ---------------------------------------------------------------------------

(define l2 (lay '((label main) (beq t0 t1 (keep))   ; 让 keep 可达
                  (jal x0 (cold))                   ; 目标不是紧邻下一块
                  (label keep) (jal x0 (keep))
                  (label cold) (addi a1 a1 1))
                '()
                '((segments (segment prog1     code #x100000 #x100FFF 4)
                            (segment prog1cold code #x300000 #x300FFF 4))
                  ;; place 行书写顺序无所谓, 段内仍按源顺序
                  (place prog1cold (cold))
                  (place prog1 (keep) (main)))))

(check-equal? (items-of-seg l2 'prog1)
              '((offset 0 (label main)) (offset 0 (beq t0 t1 (keep)))
                (offset 4 (jal x0 (cold)))
                (offset 8 (label keep)) (offset 8 (jal x0 (keep)))))
(check-equal? (items-of-seg l2 'prog1cold)
              '((offset 0 (label cold)) (offset 0 (addi a1 a1 1))))
(check-equal? (size-of-seg l2 'prog1) 12)
(check-equal? (size-of-seg l2 'prog1cold) 4)

;; jal 跨段 2MB -> needs-far, 留给 far 层
(check-equal? (problems-of l2)
              '((needs-far prog1 4 (jal x0 (cold)) 2097148 (code 1 0))))

;; ---------------------------------------------------------------------------
;; fallthrough: 顺序执行被拆到两个段 -> 必须报
;; ---------------------------------------------------------------------------

(check-equal? (problems-of
               (lay '((label a) (addi a0 a0 1) (beq t0 t1 (a))   ; 这条把块切开
                      (label b) (addi a1 a1 1))
                    '()
                    '((segments (segment s1 code #x1000 #x1FFF 4)
                                (segment s2 code #x2000 #x2FFF 4))
                      (place s1 (a))
                      (place s2 (b)))))
              '((broken-fallthrough 0 1 ((a)) ((b)))))

;; 同一个段里紧挨着 -> 没问题
(check-equal? (problems-of
               (lay '((label a) (addi a0 a0 1) (beq t0 t1 (a))
                      (label b) (addi a1 a1 1))
                    '()
                    '((segments (segment s1 code #x1000 #x1FFF 4))
                      (place s1 (a) (b)))))
              '())

;; 中间夹一个别的 region 也会断
(check-equal? (problems-of
               (lay '((label a) (addi a0 a0 1)
                      (label x) (jal ra (x))          ; 调用自己, 并顺序落到 b
                      (label b) (addi a1 a1 1))
                    '()
                    '((segments (segment s1 code #x1000 #x1FFF 4)
                                (segment s2 code #x2000 #x2FFF 4))
                      (place s1 (a) (b))
                      (place s2 (x)))))
              '((broken-fallthrough 0 1 ((a)) ((x)))
                (broken-fallthrough 1 2 ((x)) ((b)))))

;; ---------------------------------------------------------------------------
;; region: 没有 label 的块跟随前面的锚点
;; ---------------------------------------------------------------------------

(define l3 (lay '((label a) (beq t0 t1 (c)) (addi a0 a0 1) (label c) (addi a1 a1 1))
                '()
                '((segments (segment s1 code #x1000 #x1FFF 4))
                  (place s1 (a) (c)))))

(check-equal? (items-of-seg l3 's1)
              '((offset 0 (label a)) (offset 0 (beq t0 t1 (c))) (offset 4 (addi a0 a0 1))
                (offset 8 (label c)) (offset 8 (addi a1 a1 1))))
(check-equal? (problems-of l3) '())

;; 把 (c) 放到另一个段: 无 label 的块跟着 (a) 走, 于是 fallthrough 断了
(check-equal? (problems-of
               (lay '((label a) (beq t0 t1 (c)) (addi a0 a0 1) (label c) (addi a1 a1 1))
                    '()
                    '((segments (segment s1 code #x1000 #x1008 4)
                                (segment s2 code #x1FF8 #x2FFF 4))
                      (place s1 (a))
                      (place s2 (c)))))
              '((broken-fallthrough 1 2 () ((c)))))

;; ---------------------------------------------------------------------------
;; 一个位置多个名字: 命中任意一条链都算
;; ---------------------------------------------------------------------------

(define l4 (lay '((label a b) (label alias) (addi a0 a0 1))
                '()
                '((segments (segment s1 code #x1000 #x1FFF 4))
                  (place s1 (alias)))))

(check-equal? (items-of-seg l4 's1)
              '((offset 0 (label a b)) (offset 0 (label alias)) (offset 0 (addi a0 a0 1))))
(check-equal? (problems-of l4) '())

;; ---------------------------------------------------------------------------
;; align 按**绝对地址**对齐 (start + cursor), 不是段内 cursor
;; ---------------------------------------------------------------------------

;; 数据: 段 start = #x2002, 先放 1 字节 => 绝对 #x2003;
;; align 8 => 补到 #x2008 (= 偏移 6), 不是补到偏移 8
(define l-abs-align
  (lay '((label main) (addi a0 a0 1))
       '((label d1) (bytes 1) (align 8) (bytes 2))
       '((segments (segment s1 code #x1004 #x10FF 4)
                   (segment d1 data #x2002 #x20FF 2))
         (place s1 (main)) (place d1 (d1)))))

(check-equal? (items-of-seg l-abs-align 'd1)
              '((offset 0 (label d1)) (offset 0 (bytes 1))
                (offset 1 (align 8)) (offset 6 (bytes 2))))
(check-equal? (size-of-seg l-abs-align 'd1) 7)
(check-equal? (problems-of l-abs-align) '())

;; 代码同构: 段 start = #x1004 (4 对齐但不 16 对齐), align 16 => 补到 #x1010
(define l-abs-align-code
  (lay '((label main) (align 16) (addi a0 a0 1))
       '()
       '((segments (segment s1 code #x1004 #x10FF 4))
         (place s1 (main)))))

(check-equal? (items-of-seg l-abs-align-code 's1)
              '((offset 0 (label main)) (offset 0 (align 16))
                (offset 12 (addi a0 a0 1))))
(check-equal? (size-of-seg l-abs-align-code 's1) 16)
(check-equal? (problems-of l-abs-align-code) '())

;; ---------------------------------------------------------------------------
;; 数据/代码分界: L5 只认自己的数据词汇, 其余一律"不透明代码, 4 字节"
;; ---------------------------------------------------------------------------

;; 不是本层的数据词汇 -> 当成不透明代码, 只给尺寸, 不问它是什么
(check-equal? (item-kind '(addi a0 a0 1)) 'code)
(check-equal? (item-size '(addi a0 a0 1)) 4)
(check-equal? (item-size '(lwu t0 sp 8)) 4)          ; 不认识也是 4, 不报错
(check-equal? (item-size '(c.lwsp t0 4)) 2)          ; c.* 一律 2
;; 数据词汇只有四个: label / bytes / fill / align
(for ([it (in-list '((label d t) (bytes 1 2) (fill 8 0) (align 4)))])
  (check-false (eq? (item-kind it) 'code)))

;; ---------------------------------------------------------------------------
;; data 段: bytes / fill / align / label
;; ---------------------------------------------------------------------------

(define l5 (lay '((label main) (la t0 (data1 table)) (ld t1 t0 0) (jalr x0 ra 0))
                '((label data1 table) (bytes 1 2 3 4) (align 8)
                  (label data1 end) (bytes 0))
                '((segments (segment prog1 code #x100000 #x1000FF 4)
                            (segment data1 data #x001000 #x0010FF 16))
                  (place prog1 (main))
                  (place data1 (data1 table) (data1 end)))))

(check-equal? (items-of-seg l5 'prog1)
              '((offset 0 (label main)) (offset 0 (la t0 (data1 table)))
                (offset 8 (ld t1 t0 0)) (offset 12 (jalr x0 ra 0))))
(check-equal? (items-of-seg l5 'data1)
              '((offset 0 (label data1 table)) (offset 0 (bytes 1 2 3 4))
                (offset 4 (align 8)) (offset 8 (label data1 end)) (offset 8 (bytes 0))))
(check-equal? (size-of-seg l5 'data1) 9)
(check-equal? (problems-of l5) '())

;; ---------------------------------------------------------------------------
;; 放置问题
;; ---------------------------------------------------------------------------

;; 没有 place 行 -> 块没有家
(check-equal? (problems-of (lay '((label main) (addi a0 a0 1)) '()
                               '((segments (segment s1 code #x1000 #x1FFF 4)))))
              '((unplaced-block 0 ((main)))))

;; 后续块跟随锚点, 不需要单独 place
(check-equal? (problems-of (lay '((label main) (addi a0 a0 1) (addi a0 a0 1)) '()
                               '((segments (segment s1 code #x1000 #x1FFF 4))
                                 (place s1 (main)))))
              '())

;; place 指向不存在的段
(check-equal? (problems-of (lay '((label main)) '()
                               '((segments (segment s1 code #x1000 #x1FFF 4))
                                 (place nope (main)))))
              '((unknown-segment nope) (unplaced-block 0 ((main)))))

;; 同一个链被两行 place 抢
(check-equal? (problems-of (lay '((label main)) '()
                               '((segments (segment a code #x1000 #x1FFF 4)
                                           (segment b code #x2000 #x2FFF 4))
                                 (place a (main))
                                 (place b (main)))))
              '((ambiguous-placement (main) a b)))

;; data 开头没有 label
(check-equal? (problems-of (lay '((label main)) '((bytes 1))
                               '((segments (segment d data #x1000 #x1FFF 4))
                                 (place d (main)))))
              '((unlabeled-run ((bytes 1)))))

;; 指令落进 data 段
(check-equal? (problems-of (lay '((label main) (addi a0 a0 1)) '()
                               '((segments (segment d data #x1000 #x1FFF 4))
                                 (place d (main)))))
              '((data-code-mixed d 0 (addi a0 a0 1))))

;; bytes 落进 code 段
(check-equal? (problems-of (lay '((label main) (bytes 1 2)) '()
                               '((segments (segment s1 code #x1000 #x1FFF 4))
                                 (place s1 (main)))))
              '((code-data-mixed s1 0 (bytes 1 2))))

;; 目标不存在 / scratch 空槽
(check-equal? (problems-of (lay '((label main) (jal x0 (ghost))) '()
                               '((segments (segment s1 code #x1000 #x1FFF 4))
                                 (place s1 (main)))))
              '((undefined-target s1 0 (jal x0 (ghost)))))
(check-equal? (problems-of (lay '((label main) (branch-indirect beq a0 a1 (done))
                                  (label keep) (jal x0 (keep))   ; 让目标不是紧邻下一块
                                  (label done) (jalr x0 ra 0))
                               '()
                               '((segments (segment s1 code #x1000 #x1FFF 4))
                                 (place s1 (main) (keep) (done)))))
              '((scratch-hole s1 0 (branch-indirect beq a0 a1 (done)) (code 0 0))))

;; jump-far: 要不要 scratch 由 link 决定, 不是由"少一项"决定
(check-equal? (problems-of (lay0 '((label main) (jump-far x0 (done))
                                   (label done) (jalr x0 ra 0))
                                '()
                                '((segments (segment s1 code #x1000 #x1FFF 4))
                                  (place s1 (main) (done)))))
              '((scratch-hole s1 0 (jump-far x0 (done)) (code 0 0))))
(check-equal? (problems-of (lay0 '((label main) (jump-far x0 t0 (done))
                                   (label done) (jalr x0 ra 0))
                                '()
                                '((segments (segment s1 code #x1000 #x1FFF 4))
                                  (place s1 (main) (done)))))
              '())
;; link = ra: 是调用, 自己就是 auipc 的落点, 不需要 scratch
(check-equal? (problems-of (lay0 '((label main) (jump-far ra (done))
                                   (label done) (jalr x0 ra 0))
                                '()
                                '((segments (segment s1 code #x1000 #x1FFF 4))
                                  (place s1 (main) (done)))))
              '())
;; L4 眼里它已经是真转移了: 跳到紧邻下一块会被删掉(变成顺序落下)
(check-equal? (items-of-seg (lay '((label main) (jump-far x0 (done))
                                   (label done) (jalr x0 ra 0))
                                '()
                                '((segments (segment s1 code #x1000 #x1FFF 4))
                                  (place s1 (main) (done))))
                             's1)
              '((offset 0 (label main)) (offset 0 (label done))
                (offset 0 (jalr x0 ra 0))))

;; fill 就是"n 个同样的字节", 尺寸由重复次数给
(check-equal? (items-of-seg
               (lay '((label main) (jalr x0 ra 0))
                    '((label d z) (fill 4096 0) (label d e) (bytes 7))
                    '((segments (segment s1 code #x1000 #x1FFF 4)
                                (segment d data #x10000 #x1FFFF 8))
                      (place s1 (main)) (place d (d z) (d e))))
               'd)
              '((offset 0 (label d z)) (offset 0 (fill 4096 0))
                (offset 4096 (label d e)) (offset 4096 (bytes 7))))
;; fill 落进 code 段 -> 数据/代码混放
(check-equal? (problems-of (lay '((label main) (fill 4 0)) '()
                               '((segments (segment s1 code #x1000 #x1FFF 4))
                                 (place s1 (main)))))
              '((code-data-mixed s1 0 (fill 4 0))))

;; ---------------------------------------------------------------------------
;; 段表问题
;; ---------------------------------------------------------------------------

(check-equal? (problems-of (lay '((label main)) '()
                               '((segments (segment s1 code #x1002 #x1FFF 16))
                                 (place s1 (main)))))
              '((segment-misaligned s1 #x1002 16)))

(check-equal? (problems-of (lay '((label main)) '()
                               '((segments (segment a code #x1000 #x1FFF 4)
                                           (segment b code #x1800 #x2FFF 4))
                                 (place a (main)))))
              '((segment-overlap a b)))

(check-equal? (problems-of (lay '((label main)) '()
                               '((segments (segment a code #x1000 #x1FFF 4)
                                           (segment b code #x2000 #x1FFF 4))
                                 (place a (main)))))
              '((segment-bad-range b)))

;; 越界
(check-equal? (problems-of (lay '((label main) (addi a0 a0 1) (addi a0 a0 1)) '()
                               '((segments (segment s1 code #x1000 #x1007 4))
                                 (place s1 (main)))))
              '((segment-overflow s1 8 7)))

;; ---------------------------------------------------------------------------
;; 边界: D1 的输出必须能被 L5 原样度量 (D1 的词汇就是 L5 的数据词汇)
;; ---------------------------------------------------------------------------

(define d1-items
  (expand-data '((label d t)
                 (b8 1) (b16 258) (b32 #x12345678) (b64 -1)
                 (b64 (label+ (d t) 8))          ; 数据里的地址字
                 (utf-string "abc")
                 (b8-array 4096 0)
                 (align 8))))

;; D1 只吐 label / bytes / fill / value / align
(check-equal? (filter (lambda (it) (not (memq (car it) '(label bytes fill value align)))) d1-items)
              '())

;; 每一条都能度量, 且都是数据
(check-equal? (for/list ([it (in-list d1-items)] #:when (fill-form? it)) (item-size it))
              '(4096))
(check-equal? (for/list ([it (in-list d1-items)] #:unless (label-form? it)) (item-kind it))
              '(data data data data data data data both))
(check-equal? (for/list ([it (in-list d1-items)] #:unless (or (label-form? it) (align-form? it)))
                       (item-size it))
              '(1 2 4 8 8 3 4096))

;; 和 L5 一起跑: 偏移正确, 没有 problem
(define d1-laid
  (layout-program (analyze '((label main) (jalr x0 ra 0)))
                  d1-items
                  '((segments (segment s1 code #x1000 #x1FFF 4)
                              (segment d data #x10000 #x1FFFF 8))
                    (place s1 (main)) (place d (d t)))))
(check-equal? (problems-of d1-laid) '())
(check-equal? (items-of-seg d1-laid 'd)
              '((offset 0 (label d t))
                (offset 0 (value 1 1))
                (offset 1 (value 2 258))
                (offset 3 (value 4 #x12345678))
                (offset 7 (value 8 -1))
                (offset 15 (value 8 (label+ (d t) 8)))
                (offset 23 (bytes 97 98 99))
                (offset 26 (fill 4096 0))
                (offset 4122 (align 8))))
(check-equal? (size-of-seg d1-laid 'd) 4128)

;; 数据里的地址字: 值由 L7 落, 但 L5 已经能查"链在不在"和"放不放得下"
(check-equal? (problems-of
               (lay0 '((label main) (jalr x0 ra 0))
                     '((label d t) (value 8 (label+ (ghost) 0)))
                     '((segments (segment s1 code #x1000 #x1FFF 4)
                                 (segment d data #x10000 #x1FFFF 8))
                       (place s1 (main)) (place d (d t)))))
              '((undefined-target d 0 (value 8 (label+ (ghost) 0)))))

;; 4 字节放不下这个地址 -> 和 needs-far 同一批(布局范围问题)
(check-equal? (problems-of
               (lay0 '((label main) (jalr x0 ra 0))
                     '((label d t) (value 4 (label+ (d t) 0)))
                     '((segments (segment s1 code #x1000 #x1FFF 4)
                                 (segment d data #x100000000 #x100000FFF 8))
                       (place s1 (main)) (place d (d t)))))
              '((value-out-of-range d 0 (value 4 (label+ (d t) 0)) #x100000000)))

;; 放得下就没有 problem
(check-equal? (problems-of
               (lay0 '((label main) (jalr x0 ra 0))
                     '((label d t) (value 8 (label+ (d t) 8)))
                     '((segments (segment s1 code #x1000 #x1FFF 4)
                                 (segment d data #x10000 #x1FFFF 8))
                       (place s1 (main)) (place d (d t)))))
              '())

;; ---------------------------------------------------------------------------
;; 端到端: 数据里的函数指针 (数据必须喂给 L3)
;; ---------------------------------------------------------------------------

(define table-prog
  '((label main) (la t0 (d table)) (ld t1 t0 0) (jalr ra t1 0)
    (jalr x0 ra 0)
    (label f) (addi a0 a0 1) (jalr x0 ra 0)))

(define table-data (expand-data '((label d table) (b64-array 1 (label+ (f) 0)))))

(define table-layout
  '((segments (segment s code #x100000 #x100FFF 4)
              (segment t data #x200000 #x2000FF 8))
    (place s (main) (f)) (place t (d table))))

;; 不把 data 喂给 L3: f 没有外部引用 -> 被 L4 当死块删掉 -> 表里的地址悬空
(check-equal? (problems-of
               (layout-program (eliminate-dead (analyze table-prog))
                               table-data table-layout))
              '((unmatched-place (f))
                (undefined-target t 0 (value 8 (label+ (f) 0)))))

;; 喂给 L3: "地址被取过" -> f 成为 root -> 活下来, 没有问题
(check-equal? (problems-of
               (layout-program (eliminate-dead (analyze table-prog table-data))
                               table-data table-layout))
              '())

;; ---------------------------------------------------------------------------
;; 全程: L1 -> L2 -> L3 -> L4
;; ---------------------------------------------------------------------------

(define src
  '((module prog1
      (label main)
      (load-32 t0 sp 8)
      (jal x0 (done))
      (label dead)
      (add t7 t7 t7)
      (label done)
      (move a0 a0))))

(define-values (flat _) (flatten-inputs (list src)))
(define pipeline
  (layout-program (eliminate-dead (analyze (rewrite-program (car flat))))
                  '()
                  '((segments (segment prog1 code #x100000 #x1000FF 4))
                    (place prog1 (prog1 main) (prog1 done)))))

;; L3 已经删掉 dead 块和"跳到紧邻下一块"的 jal
(check-equal? (items-of-seg pipeline 'prog1)
              '((offset 0 (label prog1 main)) (offset 0 (lwu t0 sp 8))
                (offset 4 (label prog1 done)) (offset 4 (add a0 a0 x0))))
(check-equal? (problems-of pipeline) '())

;; place 指的是块内的位置标记(不是块头) -> 块不能拆, 报 unmatched-place
(define l-mid
  (lay '((label a) (addi a0 a0 1) (label mid) (addi a0 a0 1))
       '()
       '((segments (segment s1 code #x1000 #x1FFF 4))
         (place s1 (a) (mid)))))
(check-equal? (problems-of l-mid) '((unmatched-place (mid))))
;; 块内 label 照样有偏移(符号表里有它)
(check-equal? (findf (lambda (r) (equal? (car r) '(mid))) (symbols-of l-mid))
              '((mid) s1 4 #x1004))

;; place 名字写错 -> 也报 unmatched-place
(check-equal? (problems-of (lay '((label a) (addi a0 a0 1)) '()
                               '((segments (segment s1 code #x1000 #x1FFF 4))
                                 (place s1 (a) (typo)))))
              '((unmatched-place (typo))))

;; 块字段形状不对 -> 解析阶段就报(这不是跨层守卫, 是 L4 自己的输入语法)
(check-exn exn:fail?
  (lambda () (layout-program '((block (id 0) (labels ((a))) (insns (addi a0 a0 1)) (fallthrough #f)))
                             '() '())))
(check-exn exn:fail?
  (lambda () (layout-program '((block (id 0) (labels (a)) (insns ((addi a0 a0 1))) (fallthrough #f)))
                             '() '())))
(check-exn exn:fail?
  (lambda () (layout-program '((block (id 0) (labels ()) (insns) (fallthrough #f)))
                             '() '())))

(displayln "L5 tests: ok")
