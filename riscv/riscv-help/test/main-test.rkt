#lang racket/base

;; ============================================================
;; main.rkt 对外入口
;; ============================================================

(require rackunit
         "../main.rkt")

;; 常量 / 绝对地址
(check-equal? (li 'a0 5) '((addi a0 x0 5)))
(check-equal? (li-size 5) 4)

;; PC 相对地址
(check-equal? (load-pcrel 'a0 8)
              '((auipc a0 0) (addi a0 a0 8)))
(check-equal? (load-pcrel-size 8) 8)

;; gp / 栈帧相对地址
(check-equal? (la-gp 'a0 16) '((addi a0 gp 16)))
(check-equal? (la-frame 'a0 'sp 16) '((addi a0 sp 16)))

;; 跳转和分支
(check-equal? (jump-cj 8) '((c.j 8)))
(check-equal? (jump-jal 'ra 8) '((jal ra 8)))
(check-equal? (branch-c 'c.beqz 'a0 8) '((c.beqz a0 8)))
(check-equal? (branch-b 'beq 'a0 'a1 8) '((beq a0 a1 8)))

;; 分支 / 跳转 / gp 选择需要的范围判断
(check-true (fits-s12? 2047))
(check-false (fits-s12? 2048))
(check-true (fits-cjump? 2046))
(check-false (fits-cjump? 2048))
(check-true (fits-branch? 4094))
(check-false (fits-branch? 4096))
(check-true (fits-cbranch? 254))
(check-false (fits-cbranch? 256))
(check-true (fits-jal? 1048574))
(check-true (fits-jalr12? -2048))
(check-true (fits-auipc-pair? 8 'rv64))

;; scratch / 压缩寄存器选择需要的寄存器判断
(check-true (register? 'a0))
(check-equal? (register->number 'a0) 10)
(check-true (same-register? 'a0 'x10))
(check-true (zero-register? 'zero))
(check-true (compressed-branch-register? 'a0))
(check-false (compressed-branch-register? 's2))
