#lang racket/base

;; ============================================================
;; 后端不认 ABI 名
;;
;; riscv-help 的职责是"给定寄存器，展开成指令"。挑哪个寄存器(scratch、
;; gp、link、base)是前端/IR 的事; 后端只允许吐**架构名** x0..x31。
;;
;; 这条规则没法靠 review 守住, 所以这里做一次机械检查:
;; 喂 x 名进去, 展开结果里的寄存器操作数必须还是 x 名(或整数)。
;; 一旦有人在后端里写死 'gp / 't0 / 'ra, 这里立刻红。
;;
;; 注意 x0 是 ISA 规定恒零的, 不是 ABI 别名 —— 后端可以且应该用它。
;; ============================================================

(require rackunit
         racket/list
         "../li.rkt"
         "../la.rkt"
         "../jump.rkt"
         "../branch.rkt"
         "../registers.rkt")

;; 整个后端源码里都不该出现的 ABI 别名
(define abi-aliases
  '(zero ra sp gp tp fp
         t0 t1 t2 t3 t4 t5 t6
         a0 a1 a2 a3 a4 a5 a6 a7
         s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11))

;; 一条指令里"像寄存器"的操作数
(define (register-operands insn)
  (filter register? (cdr insn)))

(define (all-register-operands insns)
  (append* (for/list ([i (in-list insns)]) (register-operands i))))

;; 展开结果里每个寄存器操作数都必须是架构名(或整数)。
(define (check-architectural-only who insns)
  (for ([r (in-list (all-register-operands insns))])
    (when (symbol? r)
      (check-false (memq r abi-aliases)
                   (format "~a 吐出了 ABI 别名 ~a: ~s" who r insns))
      (check-eq? r (register-x-name r)
                (format "~a 吐出了非架构名 ~a: ~s" who r insns)))))

;; ------------------------------------------------------------
;; 各个展开器, 全部用 x 名调用
;; ------------------------------------------------------------

(define (expansions)
  (list
   ;; li: 覆盖 s12 / lui / lui+addi / addiw / zext32 / low32-zero / general64
   (cons 'li (li 'x10 5))
   (cons 'li (li 'x10 4096))
   (cons 'li (li 'x10 2048))
   (cons 'li (li 'x10 #x7fffffff))
   (cons 'li (li 'x10 #x80000000))
   (cons 'li (li 'x10 #x100000000))
   (cons 'li (li 'x10 #x123456789abcdef))

   ;; 地址
   (cons 'load-pcrel (load-pcrel 'x10 8))
   (cons 'load-pcrel (load-pcrel 'x10 #x100000000 #:scratch 'x5))
   (cons 'la-abs (la-abs 'x10 4096))
   (cons 'la-got (la-got 'x10))
   (cons 'la-gp (la-gp 'x10 'x3 16))
   (cons 'la-frame (la-frame 'x10 'x2 16))
   (cons 'la-frame (la-frame 'x10 'x2 5000 #:scratch 'x5))
   (cons 'expand-la (expand-la 'x10 8 #:mode 'pcrel))
   (cons 'expand-la (expand-la 'x10 16 #:mode 'gp #:base 'x3))
   (cons 'expand-la (expand-la 'x10 16 #:mode 'frame #:base 'x2))

   ;; 跳转
   (cons 'jump-cj (jump-cj 8))
   (cons 'jump-cjal (jump-cjal 8))
   (cons 'jump-jal (jump-jal 'x1 8))
   (cons 'jump-auipc-jalr (jump-auipc-jalr 'x1 4096))
   (cons 'jump-auipc-jalr (jump-auipc-jalr 'x0 4096 #:scratch 'x5))
   (cons 'jump-jalr (jump-jalr 'x1 'x5 8))
   (cons 'jump-pcrel-far (jump-pcrel-far 'x1 #x100000000 #:scratch 'x5))
   (cons 'jump-pcrel-far (jump-pcrel-far 'x0 #x100000000 #:scratch '(x5 x6)))
   (cons 'jump-abs (jump-abs 'x1 #x1000 #:scratch 'x5))

   ;; 分支
   (cons 'branch-c (branch-c 'c.beqz 'x10 8))
   (cons 'branch-b (branch-b 'beq 'x10 'x11 8))
   (cons 'branch-long (branch-long 'beq 'x10 'x11 1000
                                   (lambda (offset) (jump-jal 'x0 offset))))
   (cons 'branch-long (branch-long 'beq 'x10 'x11 1000
                                   (lambda (offset)
                                     (jump-auipc-jalr 'x0 offset #:scratch 'x5))))))

(for ([entry (in-list (expansions))])
  (check-architectural-only (car entry) (cdr entry)))

;; ------------------------------------------------------------
;; 调拨来的寄存器原样透传, 不被改名
;; ------------------------------------------------------------

(check-equal? (la-gp 'x10 'x3 16) '((addi x10 x3 16)))
(check-equal? (jump-jal 'x1 8) '((jal x1 8)))
(check-equal? (jump-auipc-jalr 'x1 4096) '((auipc x1 1) (jalr x1 x1 0)))
(check-equal? (jump-auipc-jalr 'x0 4096 #:scratch 'x5)
              '((auipc x5 1) (jalr x0 x5 0)))
(check-equal? (la-frame 'x10 'x2 16) '((addi x10 x2 16)))

;; ------------------------------------------------------------
;; 反过来: 前端给 ABI 名是允许的(后端不认识, 只是原样带走)
;; ------------------------------------------------------------

(check-equal? (jump-auipc-jalr 'ra 4096) '((auipc ra 1) (jalr ra ra 0)))
(check-equal? (la-gp 'a0 'gp 16) '((addi a0 gp 16)))
(check-true (zero-register? 'zero))
