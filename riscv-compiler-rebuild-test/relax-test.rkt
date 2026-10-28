#lang racket
;;; relax-test.rkt -- 分支松弛: 提升阶梯 / 收敛 / 空槽

(require rackunit
         "helpers.rkt"
         (only-in "../riscv-compiler-rebuild/relax/relax.rkt" relax far-step)
         (only-in "../riscv-compiler-rebuild/layout/layout.rkt"
                  layout-program layout-problems)
         (only-in "../riscv-compiler-rebuild/analyze/analyze.rkt"
                  analyze program-blocks program-flows))

(define (block-at prog i) (list-ref (program-blocks prog) i))
(define (flow-at prog i) (list-ref (program-flows prog) i))

;; ---------------------------------------------------------------------------
;; 提升表: 每次都只升一档
;; ---------------------------------------------------------------------------

(check-equal? (far-step '(c.beqz a0 L)) '(beq a0 x0 L))
(check-equal? (far-step '(c.bnez a0 L)) '(bne a0 x0 L))
(check-equal? (far-step '(c.j L)) '(jal x0 L))
(check-equal? (far-step '(c.jal L)) '(jal ra L))

(check-equal? (far-step '(beq a b L)) '(branch-far beq a b L))
(check-equal? (far-step '(bne a b L)) '(branch-far bne a b L))
(check-equal? (far-step '(blt a b L)) '(branch-far blt a b L))
(check-equal? (far-step '(bge a b L)) '(branch-far bge a b L))
(check-equal? (far-step '(bltu a b L)) '(branch-far bltu a b L))
(check-equal? (far-step '(bgeu a b L)) '(branch-far bgeu a b L))

(check-equal? (far-step '(branch-far beq a b L))
              '(branch-indirect beq a b L))
(check-equal? (far-step '(branch-far bne a b L))
              '(branch-indirect bne a b L))

(check-equal? (far-step '(jal ra L)) '(jump-far ra L))
(check-equal? (far-step '(jal x0 L)) '(jump-far x0 L))
(check-equal? (far-step '(jal L)) '(jump-far ra L))

(check-false (far-step '(branch-indirect beq a b L)))
(check-false (far-step '(jump-far ra L)))
(check-false (far-step '(add a b c)))
(check-false (far-step '(label f)))

;; ---------------------------------------------------------------------------
;; 边界: 区间端点 (d = 4094 / 4096, 254 / 256)
;; ---------------------------------------------------------------------------

(define (branch-at target-start branch)
  (let* ([p (program-of
             (list (list 'blocks
                         (list 'block '((main)) branch)
                         (list 'block '((far)) '(jalr x0 ra 0)))
                   (list 'flows
                         '(flow (succ 1) (fallthrough #f) (root? #t))
                         '(flow (succ) (fallthrough #f) (root? #f)))))]
         [spec (list (list 'segments
                           (list 'segment '(name c) '(kind code)
                                 (list 'start #x1000) (list 'end #x1100) '(align 16))
                           (list 'segment '(name d) '(kind code)
                                 (list 'start target-start)
                                 (list 'end (+ target-start #x1000))
                                 '(align 2)))
                     (list 'place 'c '(main))
                     (list 'place 'd '(far)))]
         [out (layout-program p '() spec)])
    out))

(check-false (has-problem? (branch-at #x1FFE '(beq a0 a0 (far))) 'needs-far))
(check-true  (has-problem? (branch-at #x2000 '(beq a0 a0 (far))) 'needs-far))

(check-false (has-problem? (branch-at #x10FE '(c.beqz a0 (far))) 'needs-far))
(check-true  (has-problem? (branch-at #x1100 '(c.beqz a0 (far))) 'needs-far))

;; ---------------------------------------------------------------------------
;; 一轮: c.beqz -> beq
;; ---------------------------------------------------------------------------

(define p-cbranch
  (program-of
   '((blocks
      (block ((main)) (c.beqz a0 (far)))
      (block ((mid)) (pad 296) (jalr x0 ra 0))
      (block ((far)) (jalr x0 ra 0)))
     (flows
      (flow (succ 2 1) (fallthrough 1) (root? #t))
      (flow (succ 2) (fallthrough 2) (root? #f))
      (flow (succ) (fallthrough #f) (root? #f))))))

(define spec-cbranch
  '((segments (segment (name c) (kind code) (start #x1000) (end #x10000) (align 16)))
    (place c (main) (mid) (far))))

(define out-cbranch (relax p-cbranch '() spec-cbranch))
(check-equal? (layout-problems out-cbranch) '())
(check-equal? (car (layout-item-forms out-cbranch 'c))
              '(label main))
(check-equal? (cadr (layout-item-forms out-cbranch 'c))
              '(beq a0 x0 (far)))
(check-equal? (layout-size out-cbranch 'c) 308)

;; ---------------------------------------------------------------------------
;; 两轮: c.beqz -> beq -> branch-far
;; ---------------------------------------------------------------------------

(define p-two-round
  (program-of
   '((blocks
      (block ((main)) (c.beqz a0 (far)))
      (block ((mid)) (pad 5000) (jalr x0 ra 0))
      (block ((far)) (jalr x0 ra 0)))
     (flows
      (flow (succ 2 1) (fallthrough 1) (root? #t))
      (flow (succ 2) (fallthrough 2) (root? #f))
      (flow (succ) (fallthrough #f) (root? #f))))))

(define spec-two-round
  '((segments (segment (name c) (kind code) (start #x1000) (end #x10000) (align 16)))
    (place c (main) (mid) (far))))

(define out-two-round (relax p-two-round '() spec-two-round))
(check-equal? (layout-problems out-two-round) '())
(check-equal? (cadr (layout-item-forms out-two-round 'c))
              '(branch-far beq a0 x0 (far)))

;; ---------------------------------------------------------------------------
;; 三级: c.beqz -> beq -> branch-far -> branch-indirect, 留下空槽
;; ---------------------------------------------------------------------------

(define p-indirect
  (program-of
   '((blocks
      (block ((main)) (c.beqz a0 (far)))
      (block ((mid)) (jalr x0 ra 0))
      (block ((far)) (jalr x0 ra 0)))
     (flows
      (flow (succ 2 1) (fallthrough 1) (root? #t))
      (flow (succ) (fallthrough #f) (root? #f))
      (flow (succ) (fallthrough #f) (root? #f))))))

(define spec-indirect
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
              (segment (name d) (kind code) (start #x200000) (end #x201000) (align 16)))
    (place c (main) (mid))
    (place d (far))))

(define out-indirect (relax p-indirect '() spec-indirect))
(check-true (has-problem? out-indirect 'scratch-hole))
(check-false (has-problem? out-indirect 'needs-far))
(check-equal? (cadr (layout-item-forms out-indirect 'c))
              '(branch-indirect beq a0 x0 (far)))

;; ---------------------------------------------------------------------------
;; jal -> jump-far: link = ra 不空槽; link = x0 空槽
;; ---------------------------------------------------------------------------

(define (jump-program jump)
  (program-of
   (list (list 'blocks
               (list 'block '((main)) jump)
               (list 'block '((mid)) '(jalr x0 ra 0))
               (list 'block '((far)) '(jalr x0 ra 0)))
         (list 'flows
               (list 'flow (list 'succ 2 1) '(fallthrough 1) '(root? #t))
               (list 'flow '(succ) '(fallthrough #f) '(root? #f))
               (list 'flow '(succ) '(fallthrough #f) '(root? #f))))))

(define spec-jump
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
              (segment (name d) (kind code) (start #x200000) (end #x201000) (align 16)))
    (place c (main) (mid))
    (place d (far))))

(define out-jump-ra (relax (jump-program '(jal ra (far))) '() spec-jump))
(check-equal? (layout-problems out-jump-ra) '())
(check-equal? (cadr (layout-item-forms out-jump-ra 'c)) '(jump-far ra (far)))

(define out-jump-x0 (relax (jump-program '(jal x0 (far))) '() spec-jump))
(check-true (has-problem? out-jump-x0 'scratch-hole))
(check-equal? (cadr (layout-item-forms out-jump-x0 'c)) '(jump-far x0 (far)))

;; ---------------------------------------------------------------------------
;; 数据不参与松弛; place / fallthrough 仍有效
;; ---------------------------------------------------------------------------

(define data '((label d t) (bytes 1 2 3) (value 4 7)))
(define spec-data
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
              (segment (name d) (kind data) (start #x2000) (end #x2100) (align 8)))
    (place c (main) (mid) (far))
    (place d (d t))))

(define out-data (relax (jump-program '(jal ra (far))) data spec-data))
(check-equal? (layout-item-forms out-data 'd)
              '((label d t) (bytes 1 2 3) (value 4 7)))
(check-equal? (layout-problems out-data) '())

;; ---------------------------------------------------------------------------
;; 防呆 / 输入类型
;; ---------------------------------------------------------------------------

;; 还有 needs-far 但轮数上限是 0: 报错
(check-error "max-rounds 保护"
             (lambda ()
               (relax p-cbranch '() spec-cbranch #:max-rounds 0)))

;; 没有 edits 时, max-rounds 0 也能返回
(check-equal? (layout-problems (relax p-cbranch '() spec-cbranch #:max-rounds 1))
              '())

;; 必须吃 analyze/dce 的 program struct
(check-error "不是 program"
             (lambda () (relax '((block ((main)) (jalr x0 ra 0)))
                               '() spec-cbranch)))

(finish-tests "relax")
