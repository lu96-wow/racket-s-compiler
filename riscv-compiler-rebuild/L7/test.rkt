#lang racket
;;; L7/test.rkt -- s-exp -> 字节

(require rackunit
         "insn.rkt"
         "encode.rkt"
         "target.rkt"
         (only-in "../L3/analyze.rkt" analyze sexp->program)
         (only-in "../L4/dce.rkt" eliminate-dead)
         (only-in "../L5/layout.rkt" layout-program layout-problems)
         (only-in "../L6/relax.rkt" relax))

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (word name . ops)
  (define-values (w n) (encode-instruction name ops))
  (cons w n))

(define (build-bytes build name)
  (define seg (findf (lambda (s) (equal? (cadr (assoc 'name (cdr s))) name)) (cdr build)))
  (bytes->list (cadr (assoc 'bytes (cdr seg)))))

(define (seg-problems out) (layout-problems out))

;; ---------------------------------------------------------------------------
;; 单条指令: 手算的标准编码
;; ---------------------------------------------------------------------------

(check-equal? (word 'add 'a0 'a1 'a2) (cons #x00c58533 4))
(check-equal? (word 'addi 'a0 'a0 1) (cons #x00150513 4))
(check-equal? (word 'beq 'a0 'a1 8) (cons #x00b50463 4))
(check-equal? (word 'sw 'a2 'a1 8) (cons #x00c5a423 4))
(check-equal? (word 'lw 'a0 'a1 8) (cons #x0085a503 4))
(check-equal? (word 'jal 'ra 8) (cons #x008000ef 4))
(check-equal? (word 'lui 'a0 #x12345) (cons #x12345537 4))
(check-equal? (word 'c.addi 'a0 1) (cons #x0505 2))
(check-equal? (word 'c.beqz 'a0 8) (cons #xc501 2))
(check-equal? (word 'c.sd 'a2 'a1 8) (cons #xe590 2))

;; 别名: riscv-asm 的 pseudo 直接可用
(check-equal? (word 'mv 'a0 'a1) (cons #x00058513 4))
(check-equal? (word 'nop) (cons #x00000013 4))
(check-equal? (word 'ret) (cons #x00008067 4))
(check-equal? (word 'ecall) (cons #x00000073 4))

;; 原子: aq/rl 是助记符后缀, 不是操作数
(check-equal? (word 'amoadd.d.aqrl 'a0 'a2 'a1) (cons #x06c5b52f 4))
(check-equal? (word 'amoadd.d 'a0 'a2 'a1) (cons #x00c5b52f 4))
(check-equal? (word 'lr.d.aq 'a0 'a1) (cons #x1405b52f 4))
(check-equal? (word 'lr.d 'a0 'a1) (cons #x1005b52f 4))

;; ---------------------------------------------------------------------------
;; 后缀 / 元数 / 未知指令
;; ---------------------------------------------------------------------------

(check-equal? (call-with-values (lambda () (split-aqrl 'amoadd.d.aqrl)) list) '(amoadd.d 1 1))
(check-equal? (call-with-values (lambda () (split-aqrl 'amoadd.d.aq)) list) '(amoadd.d 1 0))
(check-equal? (call-with-values (lambda () (split-aqrl 'amoadd.d.rl)) list) '(amoadd.d 0 1))
(check-equal? (call-with-values (lambda () (split-aqrl 'amoadd.d)) list) '(amoadd.d 0 0))
;; .rlaq 不是规范写法 -> 变成未知助记符
(check-false (known-instruction? (car (call-with-values (lambda () (split-aqrl 'amoadd.d.rlaq)) list))))
(check-exn exn:fail?
           (lambda () (encode-instruction 'amoadd.d.rlaq (list 'a0 'a2 'a1))))
;; 非原子指令不接受后缀
(check-exn exn:fail? (lambda () (encode-instruction 'add.aq (list 'a0 'a1 'a2))))

(check-equal? (instruction-arity 'beq) 3)
(check-equal? (instruction-arity 'c.beqz) 2)
(check-equal? (instruction-arity 'amoadd.d.aqrl) 3)   ; aq/rl 不算操作数
(check-equal? (instruction-arity 'nop) 0)
(check-false (instruction-arity 'no-such-instruction))

(check-exn exn:fail? (lambda () (encode-instruction 'beq (list 'a0 'a1))))
(check-exn exn:fail? (lambda () (encode-instruction 'no-such-instruction '())))
;; 越界交给 riscv-asm 报(它才是"变二进制"那一步)
(check-exn exn:fail? (lambda () (encode-instruction 'addi (list 'a0 'a1 5000))))
(check-exn exn:fail? (lambda () (encode-instruction 'c.beqz (list 's2 8))))

;; ---------------------------------------------------------------------------
;; layout -> build: 代码 + 数据
;; ---------------------------------------------------------------------------

(define prog
  '((label main) (addi a0 a0 1) (jal x0 (done)) (label done) (jalr x0 ra 0)))

(define data
  '((label d t)
    (value 4 42)
    (value 2 258)
    (value 8 (label+ (d t) 8))       ; 数据里的地址字
    (fill 3 0)
    (bytes 9 9)))

(define out
  (layout-program (eliminate-dead (analyze prog)) data
                  '((segments (segment s code #x1000 #x1FFF 4)
                              (segment d data #x8000 #x8FFF 8))
                    (place s (main) (done)) (place d (d t)))))

(check-equal? (seg-problems out) '())

(define build (encode-layout out))
(check-equal? (map car (cdr build)) '(segment segment))
(check-equal? (map (lambda (s) (cadr (assoc 'name (cdr s)))) (cdr build)) '(s d))

;; L4 已经删掉"跳到紧邻下一块"的 jal, 所以只剩 addi + jalr
(check-equal? (build-bytes build 's) '(#x13 #x05 #x15 #x00  #x67 #x80 #x00 #x00))
(check-equal? (build-bytes build 'd)
              '(42 0 0 0                 ; value 4 42
                2 1                      ; value 2 258
                8 #x80 0 0 0 0 0 0       ; value 8 (label+ (d t) 8) = 0x8008, 小端
                0 0 0                    ; fill 3 0
                9 9))                    ; bytes

;; ---------------------------------------------------------------------------
;; 对齐: code 补 nop(会顺着执行), data 补 0
;; ---------------------------------------------------------------------------

(define align-out
  (layout-program (eliminate-dead (analyze '((label main) (addi a0 a0 1)
                                             (align 16) (jalr x0 ra 0))))
                  '((label d t) (bytes 1) (align 8) (bytes 2))
                  '((segments (segment s code #x1000 #x1FFF 4)
                              (segment d data #x8002 #x8FFF 2))
                    (place s (main)) (place d (d t)))))

(check-equal? (seg-problems align-out) '())
(define align-build (encode-layout align-out))
;; 0x1004 -> 对齐到 0x1010: 12 字节 = 3 条 nop
(check-equal? (build-bytes align-build 's)
              (append '(#x13 #x05 #x15 #x00)
                      '(#x13 0 0 0 #x13 0 0 0 #x13 0 0 0)
                      '(#x67 #x80 #x00 #x00)))
;; 0x8003 -> 0x8008: 5 字节 0
(check-equal? (build-bytes align-build 'd) '(1 0 0 0 0 0 2))

;; ---------------------------------------------------------------------------
;; 远形式: L6 的产物也要能编
;; ---------------------------------------------------------------------------

(define far-prog
  (sexp->program
   '((blocks (block ((p main)) (beq t0 t1 (q cold)))
             (block () (addi a0 a0 1) (jalr x0 ra 0))
             (block ((q cold)) (addi a1 a1 1) (jalr x0 ra 0)))
     (flows (flow (succ 2 1) (fallthrough 1) (root? #t))
            (flow (succ) (fallthrough #f) (root? #f))
            (flow (succ) (fallthrough #f) (root? #f))))))

(define far-out (relax far-prog '()
                       '((segments (segment p code #x1000 #x1014 4)
                                   (segment q code #x2000 #x2FFF 4))
                         (place p (p main)) (place q (q cold)))))
(check-equal? (seg-problems far-out) '())
;; branch-far = 反向分支 + jal, 一共 8 字节
(check-equal? (length (build-bytes (encode-layout far-out) 'p)) 16)

(define far-bytes (build-bytes (encode-layout far-out) 'p))
(define w1 (+ (list-ref far-bytes 0) (arithmetic-shift (list-ref far-bytes 1) 8)
              (arithmetic-shift (list-ref far-bytes 2) 16)
              (arithmetic-shift (list-ref far-bytes 3) 24)))
(define w2 (+ (list-ref far-bytes 4) (arithmetic-shift (list-ref far-bytes 5) 8)
              (arithmetic-shift (list-ref far-bytes 6) 16)
              (arithmetic-shift (list-ref far-bytes 7) 24)))
;; 第一条: bne t0,t1,+8 (条件被反转, 跳过 jal)
(check-equal? (bitwise-and w1 #x7F) #x63)
(check-equal? (bitwise-and (arithmetic-shift w1 -12) #x7) #x1)      ; funct3 = BNE
;; B 型把 imm[4:1] 放在 bit 11..8, 所以这里存的是 8>>1 = 4
(check-equal? (bitwise-and (arithmetic-shift w1 -8) #xF) 4)
(check-equal? (bitwise-and (arithmetic-shift w1 -15) #x1F) 5)       ; rs1 = t0
(check-equal? (bitwise-and (arithmetic-shift w1 -20) #x1F) 6)       ; rs2 = t1
;; 第二条: jal x0, +4092 (0x1004 -> 0x2000)
(check-equal? (bitwise-and w2 #x7F) #x6F)
(check-equal? (bitwise-and (arithmetic-shift w2 -7) #x1F) 0)        ; rd = x0
(check-equal? w2 #x7FD0006F)

;; ---------------------------------------------------------------------------
;; 拒绝出产物 / 未实现
;; ---------------------------------------------------------------------------

;; layout 里还有 problem -> 拒绝
(check-exn exn:fail?
           (lambda ()
             (encode-layout
              (layout-program (eliminate-dead (analyze '((label main) (jal x0 (ghost)))))
                              '()
                              '((segments (segment s code #x1000 #x1FFF 4))
                                (place s (main)))))))

;; li / la 还没做
(check-exn exn:fail?
           (lambda ()
             (encode-layout
              (layout-program (eliminate-dead (analyze '((label main) (li t0 1))))
                              '()
                              '((segments (segment s code #x1000 #x1FFF 4))
                                (place s (main)))))))

(displayln "L7 tests: ok")
