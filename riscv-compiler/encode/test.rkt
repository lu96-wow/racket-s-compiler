#lang racket
;;; encode/test.rkt -- s-exp -> 字节

(require rackunit
         (rename-in "insn.rkt"
                    [encode-instruction encode-instruction*]
                    [instruction-arity instruction-arity*]
                    [known-instruction? known-instruction?*])
         (rename-in "encode.rkt" [encode-layout encode-layout*])
         "syntax/order.rkt"
         "syntax/direct.rkt"
         "syntax/coverage.rkt"
         (rename-in "../target.rkt" [padding-bytes padding-bytes*])
         (only-in "../analyze/analyze.rkt" analyze sexp->program)
         (only-in "../dce/dce.rkt" eliminate-dead)
         (rename-in "../layout/layout.rkt" [layout-program layout-program*])
         (only-in "../layout/layout.rkt" layout-problems)
         (rename-in "../relax/relax.rkt" [relax relax*]))

(define test-target target-rv64-base)
(define (encode-instruction name operands) (encode-instruction* test-target name operands))
(define (instruction-arity name) (instruction-arity* test-target name))
(define (known-instruction? name) (known-instruction?* test-target name))
(define (padding-bytes kind n) (padding-bytes* test-target kind n))
(define (encode-layout layout) (encode-layout* test-target layout))
(define (layout-program prog data spec) (layout-program* test-target prog data spec))
(define (relax prog data spec #:max-rounds [n 64])
  (relax* test-target prog data spec #:max-rounds n))

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

;; 所有 A 扩展原子指令都有 s-exp 语法: lr 2 个操作数, sc/amo 3 个
(define atomic-unary '(lr.w lr.d))
(define atomic-binary
  '(sc.w amoswap.w amoadd.w amoxor.w amoand.w amoor.w
    amomin.w amomax.w amominu.w amomaxu.w
    sc.d amoswap.d amoadd.d amoxor.d amoand.d amoor.d
    amomin.d amomax.d amominu.d amomaxu.d))
(for ([n (in-list atomic-unary)])
  (check-equal? (instruction-arity n) 2 (format "arity ~a" n))
  (define-values (_w size) (encode-instruction n (list 'a0 'a1)))
  (check-equal? size 4 (format "size ~a" n)))
(for ([n (in-list atomic-binary)])
  (check-equal? (instruction-arity n) 3 (format "arity ~a" n))
  (define-values (_w size) (encode-instruction n (list 'a0 'a2 'a1)))
  (check-equal? size 4 (format "size ~a" n)))

;; 后缀对每个原子指令都生效
(for ([n (in-list (append atomic-unary atomic-binary))])
  (define n* (string->symbol (format "~a.aqrl" n)))
  (define arity (instruction-arity n*))
  (define ops (if (= arity 2) '(a0 a1) '(a0 a2 a1)))
  (define-values (w _size) (encode-instruction n* ops))
  (check-equal? (bitwise-and w #x06000000) #x06000000
                (format "aqrl bits ~a" n*)))

;; aq/rl 只改两位
(check-equal? (word 'amoadd.d.aq 'a0 'a2 'a1) (cons #x04c5b52f 4))
(check-equal? (word 'amoadd.d.rl 'a0 'a2 'a1) (cons #x02c5b52f 4))
(check-equal? (word 'sc.d.aq 'a0 'a1 'a2) (cons #x1cb6352f 4))

;; fence: (fence) = 完整 fence; (fence pred succ) = 显式 pred/succ
;; pred/succ 是 i,o,r,w 的规范顺序组合; 0 表示空集 (LLVM 接受)
(check-equal? (word 'fence) (cons #x0ff0000f 4))
(check-equal? (word 'fence 'rw 'rw) (cons #x0330000f 4))
(check-equal? (word 'fence 'iorw 'iorw) (cons #x0ff0000f 4))
(check-equal? (word 'fence 'r 'w) (cons #x0210000f 4))
(check-equal? (word 'fence 0 0) (cons #x0000000f 4))
(check-equal? (word 'fence 0 'rw) (cons #x0030000f 4))
(check-equal? (word 'fence.tso) (cons #x8330000f 4))
(check-equal? (word 'pause) (cons #x0100000f 4))   ; fence w, 0 的别名

(check-equal? (instruction-arity 'fence) 2)        ; 显式形式
(check-equal? (instruction-arity 'fence.tso) 0)
(check-exn exn:fail? (lambda () (encode-instruction 'fence (list 'rw))))
(check-exn exn:fail? (lambda () (encode-instruction 'fence (list 'rw 'rw 'rw))))
(check-exn exn:fail? (lambda () (encode-instruction 'fence (list 'wr 'rw))))
(check-exn exn:fail? (lambda () (encode-instruction 'fence (list 'rwx 'rw))))
(check-exn exn:fail? (lambda () (encode-instruction 'fence (list 1 'rw))))
(check-exn exn:fail? (lambda () (encode-instruction 'fence.tso (list 'rw))))
(check-exn exn:fail? (lambda () (encode-instruction 'fence.tso.aq '())))

;; ---------------------------------------------------------------------------
;; CSR / fence.i
;; ---------------------------------------------------------------------------

(check-equal? (word 'csrrw 'a0 'mstatus 'a1) (cons #x30059573 4))
(check-equal? (word 'csrrs 'a0 'mstatus 'a1) (cons #x3005a573 4))
(check-equal? (word 'csrrc 'a0 'mstatus 'a1) (cons #x3005b573 4))
(check-equal? (word 'csrr 'a0 'mstatus) (cons #x30002573 4))
(check-equal? (word 'csrw 'mstatus 'a1) (cons #x30059073 4))
(check-equal? (word 'csrrwi 'a0 'mstatus 3) (cons #x3001d573 4))
(check-equal? (word 'csrwi 'mstatus 3) (cons #x3001d073 4))
(check-equal? (word 'fence.i) (cons #x0000100f 4))

;; CSR 也可以直接写 12 位编号
(check-equal? (word 'csrr 'a0 #x300) (cons #x30002573 4))

(check-equal? (instruction-arity 'csrrw) 3)
(check-equal? (instruction-arity 'csrr) 2)
(check-equal? (instruction-arity 'csrw) 2)
(check-equal? (instruction-arity 'csrrwi) 3)
(check-equal? (instruction-arity 'fence.i) 0)

(check-exn exn:fail? (lambda () (encode-instruction 'csrr (list 'a0 'no-such-csr))))
(check-exn exn:fail? (lambda () (encode-instruction 'csrwi (list 'mstatus 'x))))
;; csrs32 只属于 rv32 profile
(check-exn exn:fail? (lambda () (encode-instruction 'csrr (list 'a0 'cycleh))))
(check-equal? (let-values ([(w _) (encode-instruction* target-rv32-all 'csrr '(a0 cycleh))]) w)
              #xc8002573)


;; 本切片自身的扩展覆盖
(check-equal? (hash-ref (syntax-coverage '(rv_zicsr rv_zifencei)) 'missing) 0)

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

;; layout -> build 的小工具: src + data + layout 输入 -> build
(define (encode-one-layout src data layout)
  (encode-layout (layout-program (eliminate-dead (analyze src)) data layout)))

;; ---------------------------------------------------------------------------
;; layout -> build: 代码 + 数据
;; ---------------------------------------------------------------------------

(define prog
  '((label main) (addi a0 a0 1) (jal x0 (done)) (label done) (jalr x0 ra 0)))

(define data
  '((label d t)
    (value 4 42)
    (value 2 258)
    (value 8 (+ (d t) 8))       ; 数据里的地址字
    (fill 3 0)
    (bytes 9 9)))

(define out
  (layout-program (eliminate-dead (analyze prog)) data
                  '((segments (segment (name s) (kind code) (start #x1000) (end #x1FFF) (align 4))
                              (segment (name d) (kind data) (start #x8000) (end #x8FFF) (align 8)))
                    (place s (main) (done)) (place d (d t)))))

(check-equal? (seg-problems out) '())

(define build (encode-layout out))
(check-equal? (map car (cdr build)) '(segment segment))
(check-equal? (map (lambda (s) (cadr (assoc 'name (cdr s)))) (cdr build)) '(s d))
;; 最终产物也带 kind: loader 靠它决定可执行/可写
(check-equal? (map (lambda (s) (cadr (assoc 'kind (cdr s)))) (cdr build)) '(code data))

;; dce 已经删掉"跳到紧邻下一块"的 jal, 所以只剩 addi + jalr
(check-equal? (build-bytes build 's) '(#x13 #x05 #x15 #x00  #x67 #x80 #x00 #x00))
(check-equal? (build-bytes build 'd)
              '(42 0 0 0                 ; value 4 42
                2 1                      ; value 2 258
                8 #x80 0 0 0 0 0 0       ; value 8 (+ (d t) 8) = 0x8008, 小端
                0 0 0                    ; fill 3 0
                9 9))                    ; bytes

;; 差值: (d end) - (d start) = 4, 落字节 04 00 00 00
(check-equal? (build-bytes (encode-one-layout
                            '((label main) (ret))
                            '((label d start) (fill 4 0) (label d end)
                              (value 4 (- (d end) (d start)))
                              (value 4 (+ (- (d end) (d start)) 2))
                              (value 4 (- (d end) (d start) 2)))
                            '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4))
                                        (segment (name d) (kind data) (start #x8000) (end #x8FFF) (align 8)))
                              (place c (main)) (place d (d start) (d end))))
                             'd)
              '(0 0 0 0               ; fill 4 0（表的 4 个字节）
                4 0 0 0               ; end - start = 4
                6 0 0 0               ; 4 + 2
                2 0 0 0))             ; 4 - 2

;; ---------------------------------------------------------------------------
;; 对齐: code 补 nop(会顺着执行), data 补 0
;; ---------------------------------------------------------------------------

(define align-out
  (layout-program (eliminate-dead (analyze '((label main) (addi a0 a0 1)
                                             (align 16) (jalr x0 ra 0))))
                  '((label d t) (bytes 1) (align 8) (bytes 2))
                  '((segments (segment (name s) (kind code) (start #x1000) (end #x1FFF) (align 4))
                              (segment (name d) (kind data) (start #x8002) (end #x8FFF) (align 2)))
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

;; code 段补 2 字节时用 c.nop（4 字节对齐够不到的地方）
(define pad2-out
  (layout-program (eliminate-dead (analyze '((label main) (c.addi a0 1)
                                             (align 4) (ret))))
                  '()
                  '((segments (segment (name s) (kind code) (start #x1000) (end #x1FFF) (align 4)))
                    (place s (main)))))
(check-equal? (seg-problems pad2-out) '())
;; c.addi a0,1 (2B) + c.nop (2B) + ret (4B)
(check-equal? (build-bytes (encode-layout pad2-out) 's)
              '(#x05 #x05  #x01 #x00  #x67 #x80 #x00 #x00))

;; 填充策略用的 nop 字面量必须和 riscv-asm 编出来的一致(两处事实钉在一起)
(define nop-word (car (call-with-values (lambda () (encode-instruction 'nop '())) list)))
(define c-nop-word (car (call-with-values (lambda () (encode-instruction 'c.addi (list 'x0 0))) list)))
(check-equal? (padding-bytes 'code 4) (integer->bytes 4 nop-word))
(check-equal? (padding-bytes 'code 2) (integer->bytes 2 c-nop-word))
(check-equal? (padding-bytes 'code 6)
              (append (integer->bytes 4 nop-word) (integer->bytes 2 c-nop-word)))

;; 填充策略本身
(check-equal? (padding-bytes 'code 0) '())
(check-equal? (padding-bytes 'code 2) '(#x01 #x00))                       ; c.nop
(check-equal? (padding-bytes 'code 4) '(#x13 #x00 #x00 #x00))             ; nop
(check-equal? (padding-bytes 'code 6) '(#x13 #x00 #x00 #x00 #x01 #x00))   ; 4 + 2
(check-equal? (padding-bytes 'data 3) '(0 0 0))
(check-exn exn:fail? (lambda () (padding-bytes 'code 3)))                 ; 奇数字节编不出来

;; ---------------------------------------------------------------------------
;; 远形式: relax 的产物也要能编
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
                       '((segments (segment (name p) (kind code) (start #x1000) (end #x1014) (align 4))
                                   (segment (name q) (kind code) (start #x2000) (end #x2FFF) (align 4)))
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
                              '((segments (segment (name s) (kind code) (start #x1000) (end #x1FFF) (align 4)))
                                (place s (main)))))))

;; ---------------------------------------------------------------------------
;; li / la
;; ---------------------------------------------------------------------------


;; li 的尺寸由常量决定(4/8/16…), 编码就是 riscv-help 的展开
(check-equal? (build-bytes (encode-one-layout '((label main) (li t0 0)) '()
                                             '((segments (segment (name s) (kind code) (start #x1000) (end #x1FFF) (align 4)))
                                               (place s (main))))
                             's)
              '(#x93 #x02 #x00 #x00))                       ; addi t0, x0, 0
(check-equal? (build-bytes (encode-one-layout '((label main) (li t0 #x12345678)) '()
                                             '((segments (segment (name s) (kind code) (start #x1000) (end #x1FFF) (align 4)))
                                               (place s (main))))
                             's)
              (append '(#xB7 #x52 #x34 #x12)                ; lui t0, 74565
                      '(#x93 #x82 #x82 #x67)))              ; addi t0, t0, 1656

;; la: 近形式 = auipc + addi; 0x1000 -> 0x8000, delta = 0x7000
(check-equal? (build-bytes (encode-one-layout '((label main) (la t0 (d t)) (ret))
                                             '((label d t) (bytes 1))
                                             '((segments (segment (name s) (kind code) (start #x1000) (end #x1FFF) (align 4))
                                                         (segment (name d) (kind data) (start #x8000) (end #x8FFF) (align 8)))
                                               (place s (main)) (place d (d t))))
                             's)
              (append '(#x97 #x72 #x00 #x00)                ; auipc t0, 7
                      '(#x93 #x82 #x02 #x00)                ; addi t0, t0, 0
                      '(#x67 #x80 #x00 #x00)))              ; ret

;; la 的显式 scratch 在近形式里用不上, 尺寸/编码都不变
(check-equal? (build-bytes (encode-one-layout '((label main) (la t0 t2 (d t)))
                                             '((label d t) (bytes 1))
                                             '((segments (segment (name s) (kind code) (start #x1000) (end #x1FFF) (align 4))
                                                         (segment (name d) (kind data) (start #x8000) (end #x8FFF) (align 8)))
                                               (place s (main)) (place d (d t))))
                             's)
              '(#x97 #x72 #x00 #x00 #x93 #x82 #x02 #x00))

;; ---------------------------------------------------------------------------
;; 语法拆分: 局部表 + 覆盖报告
;; ---------------------------------------------------------------------------

(check-not-false (member "rd rs1 rs2 aq rl" (order-plan-keys)))
(check-not-false (member "bimm12 rs1 rs2" (order-plan-keys)))
(check-equal? (direct-plan-names) '(fence fence.i fence.tso))

;; 当前 target 的扩展必须全部有语法计划
(check-equal? (hash-ref (syntax-coverage (target-extensions test-target)) 'missing) 0)

;; 全量 riscv-asm 扩展仍然缺语法; 这是后续工作的清单来源
(check-true (positive? (hash-ref (syntax-coverage) 'missing)))

(displayln "encode tests: ok")
