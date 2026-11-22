#lang racket/base
;;; size.rkt: 统一指令长度

(require rackunit
         racket/list
         "../size.rkt")

;; native / compressed
(check-equal? (instruction-size '(add a0 a1 a2)) 4)
(check-equal? (instruction-size '(c.addi a0 1)) 2)
(check-equal? (instruction-size '(nop)) 4)
(check-equal? (instruction-size '(c.nop)) 2)

;; li 由常量精确决定
(check-equal? (instruction-size '(li a0 5)) 4)
(check-equal? (instruction-size '(li a0 2048)) 8)
(check-equal? (instruction-size '(li a0 #x123456789abcdef)) 32)
(check-equal? (instruction-size '(li a0 2048) #:word-size 'rv32) 8)
(check-equal? (instruction-size '(li a0 5) #:word-size 'rv32) 4)

;; 地址
(check-equal? (instruction-size '(la-pcrel a0 (x))) 8)
(check-equal? (instruction-size '(la-pcrel-li-add a0 t0 (x))) 40)
(check-equal? (instruction-size '(la-pcrel-li-add a0 t0 (x)) #:word-size 'rv32) 16)

;; 显式控制转移
(check-equal? (instruction-size '(branch-jal beq a0 a1 (x))) 8)
(check-equal? (instruction-size '(branch-auipc-jalr t0 beq a0 a1 (x))) 12)
(check-equal? (instruction-size '(jump-auipc-jalr ra ra (x))) 8)

;; 多条求和
(check-equal? (instructions-size '((add a0 a1 a2)
                                   (c.addi a0 1)
                                   (li a0 2048)
                                   (branch-jal beq a0 a1 (x))))
              (+ 4 2 8 8))

;; 非法输入
(check-exn exn:fail? (lambda () (instruction-size 'not-an-instruction)))
(check-exn exn:fail? (lambda () (instruction-size '(li a0 5 6))))

(let ()
  (displayln "size tests: ok"))
