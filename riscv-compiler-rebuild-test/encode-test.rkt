#lang racket
;;; encode-test.rkt -- 指令字 / 端序 / 填充 / layout -> build

(require rackunit
         "helpers.rkt"
         (only-in "../riscv-compiler-rebuild/encode/insn.rkt"
                  encode-instruction instruction-arity known-instruction? split-aqrl)
         (only-in "../riscv-compiler-rebuild/encode/encode.rkt"
                  encode-layout)
         (only-in "../riscv-compiler-rebuild/target.rkt"
                  target-xlen target-endianness integer->bytes padding-bytes))

(define (word name . ops)
  (define-values (w n) (encode-instruction name ops))
  (list w n))

(define (laid segments symbols)
  (list (cons 'segments segments)
        (cons 'symbols symbols)
        (cons 'problems '())))

;; ---------------------------------------------------------------------------
;; 目标事实
;; ---------------------------------------------------------------------------

(check-equal? target-xlen 'rv64)
(check-equal? target-endianness 'little)

(check-equal? (integer->bytes 4 #x12345678) '(#x78 #x56 #x34 #x12))
(check-equal? (integer->bytes 2 258) '(2 1))
(check-equal? (integer->bytes 8 #x0102030405060708)
              '(8 7 6 5 4 3 2 1))
(check-equal? (integer->bytes 1 -1) '(255))
(check-error "宽度放不下" (lambda () (integer->bytes 1 256)))

(check-equal? (padding-bytes 'data 4) '(0 0 0 0))
(check-equal? (padding-bytes 'code 4) '(#x13 0 0 0))
(check-equal? (padding-bytes 'code 8) '(#x13 0 0 0 #x13 0 0 0))
(check-equal? (padding-bytes 'code 6) '(#x13 0 0 0 #x01 0))
(check-error "code 不能补 1 字节" (lambda () (padding-bytes 'code 1)))
(check-error "code 不能补 3 字节" (lambda () (padding-bytes 'code 3)))
(check-error "未知段类型" (lambda () (padding-bytes 'bss 4)))

;; ---------------------------------------------------------------------------
;; 单条指令: 手算的标准编码
;; ---------------------------------------------------------------------------

(check-equal? (word 'add 'a0 'a1 'a2) (list #x00c58533 4))
(check-equal? (word 'add 'a0 'a1 'x0) (list #x00058533 4))
(check-equal? (word 'addi 'a0 'a0 1) (list #x00150513 4))
(check-equal? (word 'beq 'a0 'a1 8) (list #x00b50463 4))
(check-equal? (word 'sw 'a2 'a1 8) (list #x00c5a423 4))
(check-equal? (word 'lw 'a0 'a1 8) (list #x0085a503 4))
(check-equal? (word 'ld 't0 'sp 8) (list #x00813283 4))
(check-equal? (word 'jal 'ra 8) (list #x008000ef 4))
(check-equal? (word 'jalr 'x0 'ra 0) (list #x00008067 4))
(check-equal? (word 'lui 'a0 #x12345) (list #x12345537 4))
(check-equal? (word 'nop) (list #x00000013 4))
(check-equal? (word 'ret) (list #x00008067 4))

(check-equal? (word 'c.addi 'a0 1) (list #x0505 2))
(check-equal? (word 'c.beqz 'a0 8) (list #xc501 2))
(check-equal? (word 'c.sd 'a2 'a1 8) (list #xe590 2))
(check-equal? (word 'c.nop 0) (list #x0001 2))

;; 操作数顺序: 存储 / 分支 / 跳转的 s-exp 位置与函数参数位置不同
(check-equal? (word 'sw 'a2 'a1 8) (list #x00c5a423 4))
(check-equal? (word 'c.sd 'a2 'a1 8) (list #xe590 2))
(check-equal? (word 'jal 'ra 8) (list #x008000ef 4))

;; ---------------------------------------------------------------------------
;; aq / rl 后缀 / 元数 / 未知指令
;; ---------------------------------------------------------------------------

(check-true (known-instruction? 'add))
(check-true (known-instruction? 'amoadd.d))
(check-false (known-instruction? 'no-such-instruction))

(call-with-values (lambda () (split-aqrl 'amoadd.d.aqrl))
  (lambda (base aq rl)
    (check-equal? base 'amoadd.d)
    (check-equal? aq 1)
    (check-equal? rl 1)))
(call-with-values (lambda () (split-aqrl 'amoadd.d.aq))
  (lambda (base aq rl)
    (check-equal? base 'amoadd.d)
    (check-equal? aq 1)
    (check-equal? rl 0)))
(call-with-values (lambda () (split-aqrl 'amoadd.d.rl))
  (lambda (base aq rl)
    (check-equal? base 'amoadd.d)
    (check-equal? aq 0)
    (check-equal? rl 1)))
(call-with-values (lambda () (split-aqrl 'add))
  (lambda (base aq rl)
    (check-equal? base 'add)
    (check-equal? aq 0)
    (check-equal? rl 0)))
;; 拼错的后缀不认
(check-equal? (call-with-values (lambda () (split-aqrl 'amoadd.d.rlaq)) list)
              '(amoadd.d.rlaq 0 0))

;; aqrl 只改变那两位, 不改变形状
(define-values (plain _pn) (encode-instruction 'amoadd.d '(a0 a1 a2)))
(define-values (aq _an) (encode-instruction 'amoadd.d.aq '(a0 a1 a2)))
(define-values (rl _rn) (encode-instruction 'amoadd.d.rl '(a0 a1 a2)))
(define-values (aqrl _qn) (encode-instruction 'amoadd.d.aqrl '(a0 a1 a2)))
(check-not-equal? plain aq)
(check-not-equal? plain rl)
(check-equal? (bitwise-and aqrl #x06000000) #x06000000)
(check-equal? (bitwise-and aq #x04000000) #x04000000)
(check-equal? (bitwise-and rl #x02000000) #x02000000)
(check-equal? (bitwise-and plain #x06000000) 0)

(check-error "非原子指令不能带 .aq" (lambda () (encode-instruction 'add.aq '(a0 a1 a2))))
(check-error "未知指令" (lambda () (encode-instruction 'nope '(a0))))

;; 所有 A 扩展原子指令: lr 2 个操作数, sc/amo 3 个
(define atomic-unary '(lr.w lr.d))
(define atomic-binary
  '(sc.w amoswap.w amoadd.w amoxor.w amoand.w amoor.w
    amomin.w amomax.w amominu.w amomaxu.w
    sc.d amoswap.d amoadd.d amoxor.d amoand.d amoor.d
    amomin.d amomax.d amominu.d amomaxu.d))
(for ([n (in-list atomic-unary)])
  (check-equal? (instruction-arity n) 2 (format "arity ~a" n))
  (define-values (_w size) (encode-instruction n '(a0 a1)))
  (check-equal? size 4 (format "size ~a" n)))
(for ([n (in-list atomic-binary)])
  (check-equal? (instruction-arity n) 3 (format "arity ~a" n))
  (define-values (_w size) (encode-instruction n '(a0 a2 a1)))
  (check-equal? size 4 (format "size ~a" n)))

;; fence: (fence) = 完整 fence; pred/succ 按 i,o,r,w 规范顺序; 0 = 空集
(check-equal? (word 'fence) (list #x0ff0000f 4))
(check-equal? (word 'fence 'rw 'rw) (list #x0330000f 4))
(check-equal? (word 'fence 'iorw 'iorw) (list #x0ff0000f 4))
(check-equal? (word 'fence 'r 'w) (list #x0210000f 4))
(check-equal? (word 'fence 0 0) (list #x0000000f 4))
(check-equal? (word 'fence.tso) (list #x8330000f 4))
(check-equal? (word 'pause) (list #x0100000f 4))

(check-equal? (instruction-arity 'add) 3)
(check-equal? (instruction-arity 'addi) 3)
(check-equal? (instruction-arity 'sw) 3)
(check-equal? (instruction-arity 'beq) 3)
(check-equal? (instruction-arity 'c.addi) 2)
(check-equal? (instruction-arity 'amoadd.d.aqrl) 3)
(check-equal? (instruction-arity 'fence) 2)
(check-equal? (instruction-arity 'fence.tso) 0)
(check-error "元数不对" (lambda () (encode-instruction 'add '(a0 a1))))
(check-error "fence 元数不对" (lambda () (encode-instruction 'fence '(rw))))
(check-error "fence pred/succ 顺序" (lambda () (encode-instruction 'fence '(wr rw))))
(check-error "fence 只允许 0 作为数值" (lambda () (encode-instruction 'fence '(1 rw))))
(check-error "fence.tso 不接受操作数" (lambda () (encode-instruction 'fence.tso '(rw))))
(check-error "fence.tso 不接受后缀" (lambda () (encode-instruction 'fence.tso.aq '())))

;; ---------------------------------------------------------------------------
;; layout -> build: 代码 + 数据 + 对齐
;; ---------------------------------------------------------------------------

(define code-layout
  (laid
   (list (list 'segment
               '(name c) '(kind code) '(start #x1000) '(end #x1100) '(align 16)
               (cons 'items '((offset 0 (label main))
                              (offset 0 (addi a0 a0 1))
                              (offset 4 (pad 4))
                              (offset 8 (beq a0 a1 (t)))
                              (offset 12 (pad 4))
                              (offset 16 (ret))))
               '(size 20))
         (list 'segment
               '(name d) '(kind data) '(start #x2000) '(end #x2100) '(align 8)
               (cons 'items '((offset 0 (label d t))
                              (offset 0 (value 4 #x12345678))
                              (offset 4 (value 2 258))
                              (offset 6 (fill 2 #xAA))
                              (offset 8 (bytes 1 2))
                              (offset 10 (pad 2))))
               '(size 12)))
   '((symbol (main) c 0 #x1000)
     (symbol (t) c 16 #x1010)
     (symbol (d t) d 0 #x2000))))

(define build (encode-layout code-layout))
(check-equal? (build-size build 'c) 20)
(check-equal? (build-size build 'd) 12)

;; addi; nop; beq +8; nop; ret
(check-equal? (build-bytes build 'c)
              '(#x13 #x05 #x15 #x00
                #x13 #x00 #x00 #x00
                #x63 #x04 #xB5 #x00
                #x13 #x00 #x00 #x00
                #x67 #x80 #x00 #x00))

;; 端序只在数据落字节时出现
(check-equal? (build-bytes build 'd)
              '(#x78 #x56 #x34 #x12
                #x02 #x01
                #xAA #xAA
                #x01 #x02
                #x00 #x00))

;; ---------------------------------------------------------------------------
;; value 的地址表达式 + 符号表
;; ---------------------------------------------------------------------------

(define addr-layout
  (laid
   (list
    (list 'segment
          '(name d) '(kind data) '(start #x2000) '(end #x2100) '(align 8)
          (cons 'items '((offset 0 (label d t))
                         (offset 0 (value 4 (+ (d t) 4)))
                         (offset 4 (value 8 (- (d x) (d t))))))
          '(size 12))
    (list 'segment
          '(name c) '(kind code) '(start #x1000) '(end #x1100) '(align 4)
          (cons 'items '((offset 0 (label main))
                         (offset 0 (jalr x0 ra 0))))
          '(size 4)))
   '((symbol (d t) d 0 #x2000)
     (symbol (d x) d 8 #x2008)
     (symbol (main) c 0 #x1000))))

(check-equal? (build-bytes (encode-layout addr-layout) 'd)
              '(#x04 #x20 #x00 #x00
                #x08 #x00 #x00 #x00 #x00 #x00 #x00 #x00))

;; 原子 + fence 走完整 layout -> build
(define atomic-fence-layout
  (laid
   (list (list 'segment
               '(name c) '(kind code) '(start #x1000) '(end #x1100) '(align 4)
               (cons 'items '((offset 0 (label main))
                              (offset 0 (fence rw rw))
                              (offset 4 (amoadd.d.aqrl a0 a2 a1))
                              (offset 8 (fence.tso))))
               '(size 12)))
   '((symbol (main) c 0 #x1000))))

(check-equal? (build-bytes (encode-layout atomic-fence-layout) 'c)
              '(#x0f #x00 #x30 #x03       ; fence rw, rw
                #x2f #xb5 #xc5 #x06       ; amoadd.d.aqrl a0, a2, (a1)
                #x0f #x00 #x30 #x83))      ; fence.tso

;; ---------------------------------------------------------------------------
;; li / la / 远形式
;; ---------------------------------------------------------------------------

(define (one-item-layout name item size)
  (laid
   (list (list 'segment
               (list 'name name) '(kind code) '(start #x1000) '(end #x2000) '(align 4)
               (cons 'items (list (list 'offset 0 (list 'label 'main))
                                  (list 'offset 0 item)))
               (list 'size size)))
   '((symbol (main) c 0 #x1000)
     (symbol (d t) d 0 #x2000))))

(check-equal? (build-bytes (encode-layout (one-item-layout 'c '(li a0 5) 4)) 'c)
              '(#x13 #x05 #x50 #x00))
(check-equal? (build-size (encode-layout (one-item-layout 'c '(li a0 2048) 8)) 'c)
              8)

;; la 近形式: auipc + addi
(check-equal? (build-bytes
               (encode-layout
                (one-item-layout 'c '(la a0 (d t)) 8))
               'c)
              '(#x17 #x15 #x00 #x00
                #x13 #x05 #x05 #x00))

;; 远分支: 反向分支 + jal, 8 字节
(check-equal? (build-size
               (encode-layout
                (one-item-layout 'c '(branch-far beq a0 a1 (d t)) 8))
               'c)
              8)
;; 间接远分支: 反向分支 + auipc + jalr, 12 字节
(check-equal? (build-size
               (encode-layout
                (one-item-layout 'c '(branch-indirect s0 beq a0 a1 (d t)) 12))
               'c)
              12)
;; 远跳转: 8 字节
(check-equal? (build-size
               (encode-layout
                (one-item-layout 'c '(jump-far ra (d t)) 8))
               'c)
              8)

;; 空槽不能编码
(check-error "branch-indirect 空槽"
             (lambda ()
               (encode-layout
                (one-item-layout 'c '(branch-indirect beq a0 a1 (d t)) 12))))
(check-error "jump-far 空槽"
             (lambda ()
               (encode-layout
                (one-item-layout 'c '(jump-far x0 (d t)) 8))))

;; ---------------------------------------------------------------------------
;; 断言: offset / size / problems
;; ---------------------------------------------------------------------------

;; layout 说 offset 4, 实际只写了 0 字节
(check-error "offset 不一致"
             (lambda ()
               (encode-layout
                (laid
                 (list (list 'segment
                             '(name c) '(kind code) '(start #x1000) '(end #x1100) '(align 4)
                             (cons 'items '((offset 4 (addi a0 a0 1))))
                             '(size 4)))
                 '()))))

;; layout 的 size 和 items 对不上
(check-error "size 不一致"
             (lambda ()
               (encode-layout
                (laid
                 (list (list 'segment
                             '(name c) '(kind code) '(start #x1000) '(end #x1100) '(align 4)
                             (cons 'items '((offset 0 (addi a0 a0 1))))
                             '(size 8)))
                 '()))))

;; 有 problem 就拒绝出产物
(check-error "problems 非空"
             (lambda ()
               (encode-layout
                (list (cons 'segments '())
                      (cons 'symbols '())
                      (cons 'problems '((needs-far c 0 (beq a b L) 9999 (code 0 0))))))))

;; code 段 pad 奇数字节: 编不出来
(check-error "code pad 1"
             (lambda ()
               (encode-layout
                (laid
                 (list (list 'segment
                             '(name c) '(kind code) '(start #x1000) '(end #x1100) '(align 4)
                             (cons 'items '((offset 0 (pad 1))))
                             '(size 1)))
                 '()))))

(finish-tests "encode")
