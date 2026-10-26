#lang racket
;;; L4/test.rkt
;;; 段归属 = 布局输入里的 place 行, 精确匹配 label 链; 代码里没有 section。

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
;; 布局产物访问器
;; ---------------------------------------------------------------------------

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
;; 一个段: 按 label 顺序摆放, 累加字节
;; ---------------------------------------------------------------------------

(define l1
  (layout-program '((label main) (addi a0 a0 1) (bge a0 a1 (b)) (label b) (addi a1 a1 1))
                  '()
                  '((segments (segment prog1 code #x100000 #x100FFF 16))
                    (place prog1 (main) (b)))))

(check-equal? (items-of-seg l1 'prog1)
              '((@ 0 (label main)) (@ 0 (addi a0 a0 1)) (@ 4 (bge a0 a1 (b)))
                (@ 8 (label b)) (@ 8 (addi a1 a1 1))))
(check-equal? (size-of-seg l1 'prog1) 12)
(check-equal? (problems-of l1) '())

(check-equal? (findf (lambda (s) (equal? (car s) '(main))) (symbols-of l1))
              '((main) prog1 0 #x100000))
(check-equal? (findf (lambda (s) (equal? (car s) '(b))) (symbols-of l1))
              '((b) prog1 8 #x100008))

;; ---------------------------------------------------------------------------
;; 两个段: place 行决定落点, 段内保持源顺序
;; ---------------------------------------------------------------------------

(define l2
  (layout-program '((label main) (addi a0 a0 1) (jal x0 (cold))
                    (label cold) (addi a1 a1 1))
                  '()
                  '((segments (segment prog1     code #x100000 #x100FFF 4)
                              (segment prog1cold code #x300000 #x300FFF 4))
                    ;; place 行的书写顺序无所谓, 段内仍按源顺序
                    (place prog1cold (cold))
                    (place prog1 (main)))))

(check-equal? (items-of-seg l2 'prog1)
              '((@ 0 (label main)) (@ 0 (addi a0 a0 1)) (@ 4 (jal x0 (cold)))))
(check-equal? (items-of-seg l2 'prog1cold)
              '((@ 0 (label cold)) (@ 0 (addi a1 a1 1))))
(check-equal? (size-of-seg l2 'prog1) 8)
(check-equal? (size-of-seg l2 'prog1cold) 4)

;; jal 跨段 2MB -> needs-far, 留给 far 层
(check-equal? (problems-of l2)
              '((needs-far prog1 4 (jal x0 (cold)) 2097148)))

;; ---------------------------------------------------------------------------
;; 一个位置多个名字: 命中任意一条链都算匹配
;; ---------------------------------------------------------------------------

(define l3
  (layout-program '((label a b) (label alias) (addi a0 a0 1))
                  '()
                  '((segments (segment prog1 code #x1000 #x1FFF 4))
                    (place prog1 (alias)))))

(check-equal? (items-of-seg l3 'prog1)
              '((@ 0 (label a b)) (@ 0 (label alias)) (@ 0 (addi a0 a0 1))))
(check-equal? (problems-of l3) '())

;; ---------------------------------------------------------------------------
;; data 段: bytes / align / label
;; ---------------------------------------------------------------------------

(define l4
  (layout-program '((label main) (la t0 (data1 table)) (ld t1 t0 0) (jalr x0 ra 0))
                  '((label data1 table) (bytes 1 2 3 4) (align 8)
                    (label data1 end) (bytes 0))
                  '((segments (segment prog1 code #x100000 #x1000FF 4)
                              (segment data1 data #x001000 #x0010FF 16))
                    (place prog1 (main))
                    (place data1 (data1 table) (data1 end)))))

(check-equal? (items-of-seg l4 'prog1)
              '((@ 0 (label main)) (@ 0 (la t0 (data1 table)))
                (@ 8 (ld t1 t0 0)) (@ 12 (jalr x0 ra 0))))
(check-equal? (items-of-seg l4 'data1)
              '((@ 0 (label data1 table)) (@ 0 (bytes 1 2 3 4))
                (@ 4 (align 8)) (@ 8 (label data1 end)) (@ 8 (bytes 0))))
(check-equal? (size-of-seg l4 'data1) 9)
(check-equal? (problems-of l4) '())

;; ---------------------------------------------------------------------------
;; 放置问题
;; ---------------------------------------------------------------------------

;; 没有 place 行 -> 不自动落位
(check-equal? (problems-of (layout-program '((label main) (addi a0 a0 1)) '()
                                          '((segments (segment prog1 code #x1000 #x1FFF 4)))))
              '((unplaced (main))))

;; place 指向不存在的段
(check-equal? (problems-of (layout-program '((label main)) '()
                                          '((segments (segment prog1 code #x1000 #x1FFF 4))
                                            (place nope (main)))))
              '((unknown-segment nope) (unplaced (main))))

;; 同一个链被两行 place 抢
(check-equal? (sort (problems-of (layout-program '((label main)) '()
                                                 '((segments (segment a code #x1000 #x1FFF 4)
                                                             (segment b code #x2000 #x2FFF 4))
                                                   (place a (main))
                                                   (place b (main)))))
                    string<?)
              '((ambiguous-placement (main) a b)))

;; 开头的 item 没有 label -> 不知道归谁
(check-equal? (problems-of (layout-program '((addi a0 a0 1) (label main)) '()
                                          '((segments (segment prog1 code #x1000 #x1FFF 4))
                                            (place prog1 (main)))))
              '((unlabeled-run ((addi a0 a0 1)))))

;; 指令落进 data 段
(check-equal? (problems-of (layout-program '((label main) (addi a0 a0 1)) '()
                                          '((segments (segment data1 data #x1000 #x1FFF 4))
                                            (place data1 (main)))))
              '((data-code-mixed data1 0 (addi a0 a0 1))))

;; bytes 落进 code 段
(check-equal? (problems-of (layout-program '() '((label t) (bytes 1 2))
                                          '((segments (segment prog1 code #x1000 #x1FFF 4))
                                            (place prog1 (t)))))
              '((code-data-mixed prog1 0 (bytes 1 2))))

;; 目标不存在 / scratch 空槽
(check-equal? (problems-of (layout-program '((label main) (jal x0 (ghost))) '()
                                          '((segments (segment prog1 code #x1000 #x1FFF 4))
                                            (place prog1 (main)))))
              '((undefined-target prog1 0 (jal x0 (ghost)))))
(check-equal? (problems-of (layout-program '((label main) (branch-indirect a0 a1 (done))
                                            (label done) (jalr x0 ra 0))
                                          '()
                                          '((segments (segment prog1 code #x1000 #x1FFF 4))
                                            (place prog1 (main) (done)))))
              '((scratch-hole prog1 0 (branch-indirect a0 a1 (done)))))

;; ---------------------------------------------------------------------------
;; 段表问题
;; ---------------------------------------------------------------------------

(check-equal? (problems-of (layout-program '((label main)) '()
                                          '((segments (segment prog1 code #x1002 #x1FFF 16))
                                            (place prog1 (main)))))
              '((segment-misaligned prog1 #x1002 16)))

(check-equal? (problems-of (layout-program '((label main)) '()
                                          '((segments (segment a code #x1000 #x1FFF 4)
                                                      (segment b code #x1800 #x2FFF 4))
                                            (place a (main)))))
              '((segment-overlap a b)))

(check-equal? (problems-of (layout-program '((label main)) '()
                                          '((segments (segment a code #x1000 #x1FFF 4)
                                                      (segment b code #x2000 #x1FFF 4))
                                            (place a (main)))))
              '((segment-bad-range b)))

;; 越界
(check-equal? (problems-of (layout-program '((label main) (addi a0 a0 1) (addi a0 a0 1)) '()
                                          '((segments (segment prog1 code #x1000 #x1007 4))
                                            (place prog1 (main)))))
              '((segment-overflow prog1 8 7)))

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
