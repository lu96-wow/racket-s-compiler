#lang racket
;;; check-test.rkt -- 显式形式检查: 范围 / scratch / la
;;;
;;; 锁住：
;;;   - 短形式超范围 -> out-of-range problem, 不自动升级
;;;   - branch-jal / branch-auipc-jalr / jump-auipc-jalr 是显式形式, 只检查自己的范围
;;;   - scratch/base/tmp 为零或重合 -> zero-scratch / bad-scratch
;;;   - 近 la 够不着 -> la-too-far problem; la-pcrel-li-add 显式选择
;;;   - check 不改 item / offset / size

(require rackunit
         "helpers.rkt"
         (rename-in "../riscv-compiler/layout/layout.rkt"
                    [layout-program layout-program*])
         (only-in "../riscv-compiler/check/check.rkt" check-layout)
         (only-in "../riscv-compiler/target.rkt" target-rv64-base))
(define target target-rv64-base)
(define (lay prog data spec) (layout-program* target prog data spec))
(define (checked prog data spec) (check-layout target (lay prog data spec)))

(define plain-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4)))
    (place c (main))))

(define (src items) (code-of (append '((label main)) items)))

;; ---------------------------------------------------------------------------
;; 短形式
;; ---------------------------------------------------------------------------

(define near (checked (src '((beq (done) a0 a0) (label done) (jalr x0 ra 0)))
                      '()
                      plain-spec))
(check-equal? (layout-problem-list near) '())

(define far-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
              (segment (name d) (kind code) (start #x200000) (end #x201000) (align 4)))
    (place c (main))
    (place d (far))))

(check-problem
 (checked (src '((beq (far) a0 a0) (label done) (jalr x0 ra 0) (label far) (jalr x0 ra 0)))
          '()
          '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
                      (segment (name d) (kind code) (start #x200000) (end #x201000) (align 4)))
            (place c (main))
            (place d (far))))
 'out-of-range)

;; ---------------------------------------------------------------------------
;; 显式远形式
;; ---------------------------------------------------------------------------

;; branch-jal 的范围是 jal 的 ±1MiB
(define branch-jal-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
              (segment (name d) (kind code) (start #x80000) (end #x81000) (align 4)))
    (place c (main))
    (place d (far))))

(define branch-jal-out
  (checked (src '((branch-jal beq a0 a0 (far)) (label done) (jalr x0 ra 0) (label far) (jalr x0 ra 0)))
           '()
           branch-jal-spec))
(check-equal? (layout-problem-list branch-jal-out) '())
(check-equal? (layout-size branch-jal-out 'c) 12)

;; 超出 jal 的 branch-jal -> out-of-range
(check-problem
 (checked (src '((branch-jal beq a0 a0 (far)) (label done) (jalr x0 ra 0) (label far) (jalr x0 ra 0)))
          '()
          far-spec)
 'out-of-range)

;; branch-auipc-jalr = 反向分支 + auipc+jalr; 显式 scratch
(define indirect-out
  (checked (src '((branch-auipc-jalr x5 beq a0 a1 (far)) (label done) (jalr x0 ra 0) (label far) (jalr x0 ra 0)))
           '()
           far-spec))
(check-equal? (layout-problem-list indirect-out) '())
(check-equal? (layout-size indirect-out 'c) 16)

;; scratch 是 x0 -> zero-scratch
(check-problem
 (checked (src '((branch-auipc-jalr x0 beq a0 a1 (far)) (label done) (jalr x0 ra 0) (label far) (jalr x0 ra 0)))
          '()
          far-spec)
 'zero-scratch)

;; ---------------------------------------------------------------------------
;; jump-auipc-jalr
;; ---------------------------------------------------------------------------

(define jump-src (src '((jump-auipc-jalr ra ra (far)) (label done) (jalr x0 ra 0) (label far) (jalr x0 ra 0))))
(check-equal? (layout-problem-list (checked jump-src '() far-spec)) '())

;; link=x0 时 base 必须是显式 scratch; base=x0 非法
(check-problem
 (checked (src '((jump-auipc-jalr x0 x0 (far)) (label done) (jalr x0 ra 0) (label far) (jalr x0 ra 0))) '() far-spec)
 'zero-scratch)
(check-equal? (layout-problem-list
               (checked (src '((jump-auipc-jalr x0 x5 (far)) (label done) (jalr x0 ra 0) (label far) (jalr x0 ra 0)))
                        '() far-spec))
              '())

;; ---------------------------------------------------------------------------
;; la / la-pcrel-li-add
;; ---------------------------------------------------------------------------

(define la-pcrel-li-add-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
              (segment (name d) (kind data) (start #xA0000000) (end #xA0001000) (align 8)))
    (place c (main))
    (place d (far-data))))

(define la-data '((label far-data) (value 1 0)))

(check-problem
 (checked (src '((la-pcrel x10 (far-data)) (jalr x0 ra 0))) la-data la-pcrel-li-add-spec)
 'la-too-far)

(check-equal? (layout-problem-list
               (checked (src '((la-pcrel-li-add x10 x5 (far-data)) (jalr x0 ra 0)))
                        la-data la-pcrel-li-add-spec))
              '())

;; tmp 不能和 rd 重合
(check-problem
 (checked (src '((la-pcrel-li-add x10 x10 (far-data)) (jalr x0 ra 0))) la-data la-pcrel-li-add-spec)
 'bad-scratch)

;; ---------------------------------------------------------------------------
;; 未定义目标 / check 不改布局
;; ---------------------------------------------------------------------------

(check-problem
 (checked (src '((jal x0 (ghost)))) '() plain-spec)
 'undefined-target)

(define before (lay (src '((branch-jal beq a0 a0 (far)) (label done) (jalr x0 ra 0) (label far) (jalr x0 ra 0)))
                    '()
                    branch-jal-spec))
(define after (check-layout target before))
(check-equal? (cdr (assoc 'segments after)) (cdr (assoc 'segments before)))
(check-equal? (cdr (assoc 'anchors after)) (cdr (assoc 'anchors before)))

(finish-tests "check")
