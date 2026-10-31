#lang racket
;;; encode-test.rkt -- 指令字 / 端序 / 填充 / layout -> build

(require rackunit
         "helpers.rkt"
         (rename-in "../riscv-compiler/encode/insn.rkt"
                    [encode-instruction encode-instruction*]
                    [instruction-arity instruction-arity*]
                    [known-instruction? known-instruction?*]
                    [split-aqrl split-aqrl])
         (rename-in "../riscv-compiler/encode/encode.rkt"
                    [encode-layout encode-layout*])
         (rename-in "../riscv-compiler/target.rkt"
                    [target-xlen target-xlen]
                    [target-extensions target-extensions]
                    [target target]
                    [target-rv64-base target-rv64-base]
                    [target-rv64-all target-rv64-all]
                    [target-rv32-all target-rv32-all]
                    [padding-bytes padding-bytes*]))

(define test-target target-rv64-base)
(define (encode-instruction name operands) (encode-instruction* test-target name operands))
(define (instruction-arity name) (instruction-arity* test-target name))
(define (known-instruction? name) (known-instruction?* test-target name))
(define (padding-bytes kind n) (padding-bytes* test-target kind n))
(define (encode-layout layout) (encode-layout* test-target layout))

(define (word name . ops)
  (define-values (w n) (encode-instruction name ops))
  (list w n))

(define (laid segments symbols)
  (list (list 'phase 'bound)
        (cons 'segments segments)
        (cons 'anchors '())
        (cons 'symbols symbols)
        (cons 'requests '())
        (cons 'problems '())))

;; measured layout: encode 必须拒绝
(define (measured layout)
  (cons (list 'phase 'measured) (cdr layout)))

(define (with-requests layout requests)
  (list (list 'phase 'bound)
        (cons 'segments (cdr (assoc 'segments layout)))
        (cons 'anchors '())
        (cons 'symbols (cdr (assoc 'symbols layout)))
        (cons 'requests requests)
        (cons 'problems '())))

;; ---------------------------------------------------------------------------
;; 目标事实
;; ---------------------------------------------------------------------------

(check-equal? (target-xlen test-target) 'rv64)
(check-equal? (target-xlen target-rv64-base) 'rv64)
(check-equal? (target-xlen target-rv32-all) 'rv32)
(check-false (memq 'rv32_i (target-extensions target-rv64-all)))
(check-false (memq 'rv64_i (target-extensions target-rv32-all)))

;; target 切换必须影响查表, 不能复用同一个缓存
(check-true (known-instruction?* target-rv64-base 'lr.d))
(check-false (known-instruction?* target-rv32-all 'lr.d))
(check-true (known-instruction?* target-rv64-base 'lr.d))

;; 无 C 时的填充由显式 target 决定
(define no-c-target (target 'rv64 '(rv_i)))
(check-equal? (padding-bytes* no-c-target 'code 4) '(#x13 #x00 #x00 #x00))
(check-error "没有 C 就不能补 2 字节" (lambda () (padding-bytes* no-c-target 'code 2)))

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

;; CSR / Zifencei
(check-equal? (word 'csrrw 'a0 'mstatus 'a1) (list #x30059573 4))
(check-equal? (word 'csrrs 'a0 'mstatus 'a1) (list #x3005a573 4))
(check-equal? (word 'csrrc 'a0 'mstatus 'a1) (list #x3005b573 4))
(check-equal? (word 'csrr 'a0 'mstatus) (list #x30002573 4))
(check-equal? (word 'csrw 'mstatus 'a1) (list #x30059073 4))
(check-equal? (word 'csrrwi 'a0 'mstatus 3) (list #x3001d573 4))
(check-equal? (word 'csrwi 'mstatus 3) (list #x3001d073 4))
(check-equal? (word 'fence.i) (list #x0000100f 4))
(check-equal? (instruction-arity 'fence.i) 0)
(check-error "unknown CSR" (lambda () (encode-instruction 'csrr '(a0 no-such-csr))))
(check-error "rv32-only CSR 不在当前 target" (lambda () (encode-instruction 'csrr '(a0 cycleh))))
(check-equal? (let-values ([(w _) (encode-instruction* target-rv32-all 'csrr '(a0 cycleh))]) w)
              #xc8002573)

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

;; measured layout 不能直接编码
(check-error "需要 bound-layout"
             (lambda () (encode-layout (measured (laid '() '())))))

;; 有 request 就拒绝出产物
(check-error "requests 非空"
             (lambda ()
               (encode-layout
                (with-requests (laid '() '())
                               '((needs-far c 0 (beq a b L) 9999 (code 0 0)))))))

;; 有 problem 就拒绝出产物
(check-error "problems 非空"
             (lambda ()
               (encode-layout
                (list (list 'phase 'bound)
                      (cons 'segments '())
                      (cons 'anchors '())
                      (cons 'symbols '())
                      (cons 'requests '())
                      (cons 'problems '((undefined-target c 0 (jal x0 (nope)))))))))

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

;; ---------------------------------------------------------------------------
;; hole 段: 地址范围存在, 文件里没有字节
;;
;; encode 不解释洞的内容(由加载器 / 程序 / 硬件定义), 只保证位置被完整推进,
;; 然后交出一段空字节。items 只可能是 label / reserve。
;; ---------------------------------------------------------------------------

(define (hole-segment items size)
  (list 'segment
        '(name b) '(kind hole) '(start #x2000) '(end #x2100) '(align 8)
        (cons 'items items)
        (list 'size size)))

(define bss-build
  (encode-layout
   (laid (list (hole-segment '((offset 0  (label bss))
                               (offset 0  (reserve 8))
                               (offset 8  (reserve 24))
                               (offset 32 (label big))
                               (offset 32 (reserve 16)))
                             48))
         '())))

;; 位置齐全, 但一个字节也不写; size 保留
(check-equal? (build-size bss-build 'b) 48)
(check-equal? (build-bytes bss-build 'b) '())
(check-equal? (cadr (assoc 'kind (cdr (build-segment bss-build 'b)))) 'hole)
(check-equal? (cadr (assoc 'start (cdr (build-segment bss-build 'b)))) #x2000)

;; hole 段里出现要写字节的 item: layout/encode 对"这段是不是洞"理解不一致
(check-error "hole 段里有 pad"
             (lambda ()
               (encode-layout (laid (list (hole-segment '((offset 0 (pad 4))) 4)) '()))))
(check-error "hole 段里有 bytes"
             (lambda ()
               (encode-layout (laid (list (hole-segment '((offset 0 (bytes 1 2))) 2)) '()))))
(check-error "hole 段的 size 与 reserve 之和不符"
             (lambda ()
               (encode-layout (laid (list (hole-segment '((offset 0 (reserve 8))) 16)) '()))))
(check-error "hole 段的 offset 对不上"
             (lambda ()
               (encode-layout (laid (list (hole-segment '((offset 4 (reserve 8))) 8)) '()))))

(finish-tests "encode")
