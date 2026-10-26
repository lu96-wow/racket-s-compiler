#lang racket
;;; L4/test.rkt
;;; L4 吃 L3 的块列表: 放置以块为单位, place 行精确匹配 label 链,
;;; 放完检查 fallthrough 是否被剪断。

(require rackunit
         "forms.rkt"
         "layout.rkt"
         (only-in "../L1/flatten.rkt" flatten-inputs)
         (only-in "../L2/rewrite.rkt" rewrite-program)
         (only-in "../L3/opt.rkt" optimize-program))

;; ---------------------------------------------------------------------------
;; 形式表
;; ---------------------------------------------------------------------------

(check-equal? (item-size '(bge a b (l))) 4)
(check-equal? (item-size '(branch-far a b (l))) 8)
(check-equal? (item-size '(branch-indirect a b (l))) 12)
(check-equal? (item-size '(branch-indirect t0 a b (l))) 12)
(check-equal? (item-size '(jal x0 (l))) 4)
(check-equal? (item-size '(jump-far (l))) 8)
(check-equal? (item-size '(call-far (l))) 8)
(check-equal? (item-size '(la t0 (l))) 8)
(check-equal? (item-size '(label l)) 0)
(check-equal? (item-size '(bytes 1 2 3)) 3)
(check-equal? (item-size '(addi a0 a0 1)) 4)
(check-equal? (item-size '(c.addi a0 1)) 2)

(check-equal? (form-range '(bge a b (l))) 4096)
(check-equal? (form-range '(branch-far a b (l))) 1048576)
(check-false  (form-range '(branch-indirect a b (l))))
(check-equal? (form-range '(jal x0 (l))) 1048576)
(check-false  (form-range '(call-far (l))))
(check-false  (form-range '(addi a0 a0 1)))

(check-true  (scratch-hole? '(branch-indirect a b (l))))
(check-false (scratch-hole? '(branch-indirect t0 a b (l))))
(check-true  (scratch-hole? '(jump-far (l))))
(check-false (scratch-hole? '(jump-far t0 (l))))
(check-false (scratch-hole? '(bge a b (l))))

(check-equal? (item-kind '(label a)) 'marker)
(check-equal? (item-kind '(align 8)) 'both)
(check-equal? (item-kind '(bytes 1)) 'data)
(check-equal? (item-kind '(addi a0 a0 1)) 'code)

;; ---------------------------------------------------------------------------
;; 小工具: 程序 -> L3 块 -> L4 布局
;; ---------------------------------------------------------------------------

(define (lay prog data layout)
  (layout-program (optimize-program prog) data layout))

(define (segments-of layout)
  (for/list ([x (in-list (cdr layout))]
             #:when (and (pair? x) (eq? (car x) 'segment)))
    x))
(define (seg-of layout name)
  (findf (lambda (s) (equal? (cadr (assoc 'name (cdr s))) name)) (segments-of layout)))
(define (items-of-seg layout name) (cdr (assoc 'items (cdr (seg-of layout name)))))
(define (size-of-seg layout name) (cadr (assoc 'size (cdr (seg-of layout name)))))
(define (symbols-of layout) (cdr (assoc 'symbols (cdr layout))))
(define (problems-of layout) (cdr (assoc 'problems (cdr layout))))

;; ---------------------------------------------------------------------------
;; 一个段: 按块顺序摆放, 累加字节
;; ---------------------------------------------------------------------------

(define l1 (lay '((label main) (addi a0 a0 1) (bge a0 a1 (c))
                  (label b) (addi a1 a1 1)
                  (label c) (addi a2 a2 1))
                '()
                '((segments (segment prog1 code #x100000 #x100FFF 16))
                  (place prog1 (main) (b) (c)))))

(check-equal? (items-of-seg l1 'prog1)
              '((@ 0 (label main)) (@ 0 (addi a0 a0 1)) (@ 4 (bge a0 a1 (c)))
                (@ 8 (label b)) (@ 8 (addi a1 a1 1))
                (@ 12 (label c)) (@ 12 (addi a2 a2 1))))
(check-equal? (size-of-seg l1 'prog1) 16)
(check-equal? (problems-of l1) '())

(check-equal? (findf (lambda (s) (equal? (car s) '(main))) (symbols-of l1))
              '((main) prog1 0 #x100000))
(check-equal? (findf (lambda (s) (equal? (car s) '(b))) (symbols-of l1))
              '((b) prog1 8 #x100008))
(check-equal? (findf (lambda (s) (equal? (car s) '(c))) (symbols-of l1))
              '((c) prog1 12 #x10000c))

;; ---------------------------------------------------------------------------
;; 两个段: 中间用 jal x0 断开, 没有 fallthrough
;; ---------------------------------------------------------------------------

(define l2 (lay '((label main) (addi a0 a0 1) (jal x0 (cold))
                  (label keep) (jal x0 (keep))     ; 让 jal 的目标不是紧邻下一块
                  (label cold) (addi a1 a1 1))
                '()
                '((segments (segment prog1     code #x100000 #x100FFF 4)
                            (segment prog1cold code #x300000 #x300FFF 4))
                  ;; place 行书写顺序无所谓, 段内仍按源顺序
                  (place prog1cold (cold))
                  (place prog1 (keep) (main)))))

(check-equal? (items-of-seg l2 'prog1)
              '((@ 0 (label main)) (@ 0 (addi a0 a0 1)) (@ 4 (jal x0 (cold)))
                (@ 8 (label keep)) (@ 8 (jal x0 (keep)))))
(check-equal? (items-of-seg l2 'prog1cold)
              '((@ 0 (label cold)) (@ 0 (addi a1 a1 1))))
(check-equal? (size-of-seg l2 'prog1) 12)
(check-equal? (size-of-seg l2 'prog1cold) 4)

;; jal 跨段 2MB -> needs-far, 留给 far 层
(check-equal? (problems-of l2)
              '((needs-far prog1 4 (jal x0 (cold)) 2097148)))

;; ---------------------------------------------------------------------------
;; fallthrough: 顺序执行被拆到两个段 -> 必须报
;; ---------------------------------------------------------------------------

(check-equal? (problems-of
               (lay '((label a) (addi a0 a0 1) (label b) (addi a1 a1 1))
                    '()
                    '((segments (segment s1 code #x1000 #x1FFF 4)
                                (segment s2 code #x2000 #x2FFF 4))
                      (place s1 (a))
                      (place s2 (b)))))
              '((broken-fallthrough 0 1 ((a)) ((b)))))

;; 同一个段里紧挨着 -> 没问题
(check-equal? (problems-of
               (lay '((label a) (addi a0 a0 1) (label b) (addi a1 a1 1))
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
              '((@ 0 (label a)) (@ 0 (beq t0 t1 (c))) (@ 4 (addi a0 a0 1))
                (@ 8 (label c)) (@ 8 (addi a1 a1 1))))
(check-equal? (problems-of l3) '())

;; 把 (c) 放到另一个段: 无 label 的块跟着 (a) 走, 于是 fallthrough 断了
(check-equal? (problems-of
               (lay '((label a) (beq t0 t1 (c)) (addi a0 a0 1) (label c) (addi a1 a1 1))
                    '()
                    '((segments (segment s1 code #x1000 #x1FFF 4)
                                (segment s2 code #x2000 #x2FFF 4))
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
              '((@ 0 (label a b)) (@ 0 (label alias)) (@ 0 (addi a0 a0 1))))
(check-equal? (problems-of l4) '())

;; ---------------------------------------------------------------------------
;; data 段: bytes / align / label
;; ---------------------------------------------------------------------------

(define l5 (lay '((label main) (la t0 (data1 table)) (ld t1 t0 0) (jalr x0 ra 0))
                '((label data1 table) (bytes 1 2 3 4) (align 8)
                  (label data1 end) (bytes 0))
                '((segments (segment prog1 code #x100000 #x1000FF 4)
                            (segment data1 data #x001000 #x0010FF 16))
                  (place prog1 (main))
                  (place data1 (data1 table) (data1 end)))))

(check-equal? (items-of-seg l5 'prog1)
              '((@ 0 (label main)) (@ 0 (la t0 (data1 table)))
                (@ 8 (ld t1 t0 0)) (@ 12 (jalr x0 ra 0))))
(check-equal? (items-of-seg l5 'data1)
              '((@ 0 (label data1 table)) (@ 0 (bytes 1 2 3 4))
                (@ 4 (align 8)) (@ 8 (label data1 end)) (@ 8 (bytes 0))))
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
(check-equal? (problems-of (lay '((label main) (branch-indirect a0 a1 (done))
                                  (label done) (jalr x0 ra 0))
                               '()
                               '((segments (segment s1 code #x1000 #x1FFF 4))
                                 (place s1 (main) (done)))))
              '((scratch-hole s1 0 (branch-indirect a0 a1 (done)))))

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
  (layout-program (optimize-program (rewrite-program (car flat)))
                  '()
                  '((segments (segment prog1 code #x100000 #x1000FF 4))
                    (place prog1 (prog1 main) (prog1 done)))))

;; L3 已经删掉 dead 块和"跳到紧邻下一块"的 jal
(check-equal? (items-of-seg pipeline 'prog1)
              '((@ 0 (label prog1 main)) (@ 0 (lwu t0 sp 8))
                (@ 4 (label prog1 done)) (@ 4 (add a0 a0 x0))))
(check-equal? (problems-of pipeline) '())

(displayln "L4 tests: ok")
