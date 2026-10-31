#lang racket
;;; integration-test.rkt -- 整条 s-exp -> 字节 流水线

(require rackunit
         "helpers.rkt"
         (rename-in "../riscv-compiler/flow/flow.rkt" [run-flow run-flow*])
         (only-in "../riscv-compiler/target.rkt" target-rv64-base)
         (only-in "../riscv-compiler/layout/layout.rkt"
                  layout-problems)
         (only-in "../riscv-compiler/analyze/analyze.rkt"
                  program-blocks program-flows block-head
                  flow-root? flow-fallthrough))

(define test-target target-rv64-base)
(define (run-flow selector [seeds '()]) (run-flow* test-target selector seeds))

;; ---------------------------------------------------------------------------
;; ARCHITECTURE.md §6 的规范例子: 逐字节对照
;; ---------------------------------------------------------------------------

(define doc-src
  '((label main) (move a0 a1) (ble a0 a1 (hot)) (jal x0 (end))
    (label hot) (addi a0 a0 1) (jalr x0 ra 0)
    (label end) (ld t0 sp 8)))

(define doc-rich
  '((label g tab) (value 8 (main)) (utf-stringz "hi")))

(define doc-spec
  '((segments (segment (name c) (kind code) (start #x100000) (end #x100FFF) (align 16))
              (segment (name d) (kind data) (start #x200000) (end #x200FFF) (align 8)))
    (place c (main) (hot) (end))
    (place d (g tab))))

(define doc-seeds
  (list (cons 'rich-data doc-rich)
        (cons 'program-items doc-src)
        (cons 'layout-spec doc-spec)))

(define doc-out (run-flow default-flow doc-seeds))
(define doc-build (flow-value doc-out 'build))

(check-equal? (build-size doc-build 'c) 24)
(check-equal? (build-bytes doc-build 'c)
              '(#x33 #x85 #x05 #x00
                #x63 #xD4 #xA5 #x00
                #x6F #x00 #xC0 #x00
                #x13 #x05 #x15 #x00
                #x67 #x80 #x00 #x00
                #x83 #x32 #x81 #x00))

(check-equal? (build-size doc-build 'd) 11)
(check-equal? (build-bytes doc-build 'd)
              '(#x00 #x00 #x10 #x00 #x00 #x00 #x00 #x00
                #x68 #x69 #x00))

;; 中间产物: 每层大致在它该在的位置
(check-equal? (flow-value doc-out 'program-items)
              '((label main) (add a0 a1 x0) (bge a1 a0 (hot))
                (jal x0 (end))
                (label hot) (addi a0 a0 1) (jalr x0 ra 0)
                (label end) (ld t0 sp 8)))

(define doc-program (flow-value doc-out 'program))
(check-equal? (length (program-blocks doc-program)) 4)
(check-true (flow-root? (car (program-flows doc-program))))
(check-false (flow-root? (cadr (program-flows doc-program))))

(check-equal? (layout-problems (flow-value doc-out 'bound-layout)) '())

;; ---------------------------------------------------------------------------
;; 模块 + 数据侧地址字: flatten / expand-data / analyze roots 一起工作
;; ---------------------------------------------------------------------------

(define mod-prog
  '((module p
      (provide f)
      (require d)
      (label main)
      (la t0 (table))
      (ld t1 t0 0)
      (jalr ra t1 0)
      (jalr x0 ra 0)
      (label f)
      (addi a0 a0 1)
      (ret))))

(define mod-rich
  '((module d
      (provide (rename-out ((d table) table)))
      (require p)
      (label d table)
      (b64 (f))
      (utf-stringz "hi"))))

(define mod-spec
  '((segments (segment (name c) (kind code) (start #x100000) (end #x100FFF) (align 16))
              (segment (name d) (kind data) (start #x200000) (end #x200FFF) (align 8)))
    (place c (p main) (p f))
    (place d (d d table))))

(define mod-out
  (run-flow default-flow
            (list (cons 'rich-data mod-rich)
                  (cons 'program-items mod-prog)
                  (cons 'layout-spec mod-spec))))

(check-equal? (hash-ref (flow-value mod-out 'names) '(p f)) 1)

(define mod-build (flow-value mod-out 'build))
(check-equal? (build-size mod-build 'c) 28)
;; 数据里 (b64 (f)) 是 8 字节地址; 后面紧跟 "hi\0"
(check-equal? (build-size mod-build 'd) 11)
(check-equal? (build-bytes mod-build 'd)
              '(#x14 #x00 #x10 #x00 #x00 #x00 #x00 #x00
                #x68 #x69 #x00))

;; 指向代码里 (p f) 的地址: main 之后 offset 20
(check-equal? (build-bytes mod-build 'c)
              (append (list #x97 #x02 #x10 #x00       ; auipc t0, 0x100
                            #x93 #x82 #x02 #x00)      ; addi t0, t0, 0
                      (list #x03 #xB3 #x02 #x00)      ; ld t1, 0(t0)
                      (list #xE7 #x00 #x03 #x00)      ; jalr ra, t1, 0
                      (list #x67 #x80 #x00 #x00)      ; jalr x0, ra, 0
                      (list #x13 #x05 #x15 #x00)      ; addi a0, a0, 1
                      (list #x67 #x80 #x00 #x00)))    ; ret

;; 数据侧的 root: 有间接跳转时, 数据里存了 (p f) 的地址, 所以 f 是 root
(check-true (flow-root? (last (program-flows (flow-value mod-out 'program)))))

;; ---------------------------------------------------------------------------
;; rich 数据全链路: 端序 / 字符串 / 数组压缩
;; ---------------------------------------------------------------------------

(define data-rich
  '((label d t)
    (b16 258)
    (b32 #x12345678)
    (utf-stringz "hi")
    (b8-array 3 0)))

(define data-src '((label main) (ret)))
(define data-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
              (segment (name d) (kind data) (start #x2000) (end #x2100) (align 8)))
    (place c (main))
    (place d (d t))))

(define data-out
  (run-flow default-flow
            (list (cons 'rich-data data-rich)
                  (cons 'program-items data-src)
                  (cons 'layout-spec data-spec))))

(check-equal? (build-bytes (flow-value data-out 'build) 'c)
              '(#x67 #x80 #x00 #x00))
(check-equal? (build-bytes (flow-value data-out 'build) 'd)
              '(#x02 #x01                  ; b16 258, little-endian
                #x78 #x56 #x34 #x12      ; b32
                #x68 #x69 #x00           ; "hi\0"
                #x00 #x00 #x00))         ; b8-array 3 0 -> fill

;; ---------------------------------------------------------------------------
;; 原子指令 + fence 走完整流
;; ---------------------------------------------------------------------------

(define atomic-src
  '((label main)
    (fence rw rw)
    (amoadd.d.aqrl a0 a2 a1)
    (fence.tso)
    (ret)))

(define atomic-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4)))
    (place c (main))))

(define atomic-out
  (run-flow default-flow
            (list (cons 'rich-data '())
                  (cons 'program-items atomic-src)
                  (cons 'layout-spec atomic-spec))))

(check-equal? (build-bytes (flow-value atomic-out 'build) 'c)
              '(#x0f #x00 #x30 #x03       ; fence rw, rw
                #x2f #xb5 #xc5 #x06       ; amoadd.d.aqrl a0, a2, (a1)
                #x0f #x00 #x30 #x83       ; fence.tso
                #x67 #x80 #x00 #x00))     ; ret

;; ---------------------------------------------------------------------------
;; CSR + fence.i 走完整流
;; ---------------------------------------------------------------------------

(define csr-src
  '((label main)
    (csrrw a0 mstatus a1)
    (fence.i)
    (ret)))

(define csr-out
  (run-flow default-flow
            (list (cons 'rich-data '())
                  (cons 'program-items csr-src)
                  (cons 'layout-spec atomic-spec))))

(check-equal? (build-bytes (flow-value csr-out 'build) 'c)
              '(#x73 #x95 #x05 #x30    ; csrrw a0, mstatus, a1
                #x0f #x10 #x00 #x00    ; fence.i
                #x67 #x80 #x00 #x00))  ; ret

;; ---------------------------------------------------------------------------
;; 完整流里的松弛: >4KB 的普通分支升成 branch-far
;; ---------------------------------------------------------------------------

(define relax-src
  '((label main) (beq a0 a0 (far))
    (label hot) (jalr x0 ra 0)
    (label far) (ret)))
(define relax-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
              (segment (name d) (kind code) (start #x2000) (end #x2100) (align 4)))
    (place c (main) (hot))
    (place d (far))))

(define relax-out
  (run-flow default-flow
            (list (cons 'rich-data '())
                  (cons 'program-items relax-src)
                  (cons 'layout-spec relax-spec))))

(check-equal? (layout-problems (flow-value relax-out 'bound-layout)) '())
(check-not-false (memq 'branch-far (map car (layout-item-forms (flow-value relax-out 'bound-layout) 'c))))
(check-equal? (build-size (flow-value relax-out 'build) 'c) 12)

;; ---------------------------------------------------------------------------
;; li / la 也走完整流
;; ---------------------------------------------------------------------------

(define lit-src
  '((label main)
    (li t0 #x12345678)
    (la t1 (d t))
    (ret)))
(define lit-rich
  '((label d t) (utf-stringz "x")))
(define lit-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
              (segment (name d) (kind data) (start #x2000) (end #x2100) (align 8)))
    (place c (main))
    (place d (d t))))

(define lit-out
  (run-flow default-flow
            (list (cons 'rich-data lit-rich)
                  (cons 'program-items lit-src)
                  (cons 'layout-spec lit-spec))))

(check-equal? (build-size (flow-value lit-out 'build) 'c) 20) ; 8 + 8 + 4
(check-equal? (build-bytes (flow-value lit-out 'build) 'd)
              '(#x78 #x00))

;; ---------------------------------------------------------------------------
;; hole 段: 参与布局和符号绑定, 不产生文件字节
;; ---------------------------------------------------------------------------
;; 不管洞里的内容是谁清的(加载器 / 程序 / 硬件): 产物只说"这段地址存在,
;; 文件里没有它"。所以这里能验的只有两件事: 符号有地址, bytes 为空。

(define bss-items
  '((label bss) (reserve 8)
    (align 16) (label buf) (reserve 16)
    (label bss-end)))

(define bss-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
              (segment (name b) (kind hole) (start #x2000) (end #x2100) (align 8)))
    (place c (main))
    (place b (bss) (buf) (bss-end))))

;; 跳过 expand-data: hole 的 item 直接当 data-items seed 进来
(define bss-out
  (run-flow '(flatten expand-pseudo analyze dce relax bind-labels encode)
            (list (cons 'program-items '((label main) (jalr x0 ra 0)))
                  (cons 'data-items bss-items)
                  (cons 'layout-spec bss-spec))))

(define bss-build (flow-value bss-out 'build))

(check-equal? (layout-problems (flow-value bss-out 'bound-layout)) '())
(check-equal? (build-size bss-build 'b) 32)
(check-equal? (build-bytes bss-build 'b) '())
(check-equal? (cadr (assoc 'kind (cdr (build-segment bss-build 'b)))) 'hole)

;; 洞里的符号照样拿到绝对地址 = 段 start + 偏移
(check-equal? (cdr (assoc 'symbols (flow-value bss-out 'bound-layout)))
              '((symbol (main) c 0 #x1000)
                (symbol (bss) b 0 #x2000)
                (symbol (buf) b 16 #x2010)
                (symbol (bss-end) b 32 #x2020)))

;; ---------------------------------------------------------------------------
;; 错误: 未定义目标 / 空槽 不允许出产物
;; ---------------------------------------------------------------------------

(check-error "undefined target"
             (lambda ()
               (run-flow default-flow
                         (list (cons 'rich-data '())
                               (cons 'program-items '((label main) (jal x0 (nope))))
                               (cons 'layout-spec
                                     '((segments (segment (name c) (kind code)
                                                          (start #x1000) (end #x1100) (align 4)))
                                       (place c (main))))))))

(check-error "远到必须用 scratch 的分支"
             (lambda ()
               (run-flow default-flow
                         (list (cons 'rich-data '())
                               (cons 'program-items
                                     '((label main) (beq a0 a0 (far))
                                       (label hot) (jalr x0 ra 0)
                                       (label far) (ret)))
                               (cons 'layout-spec
                                     '((segments
                                        (segment (name c) (kind code)
                                                 (start #x1000) (end #x1100) (align 4))
                                        (segment (name d) (kind code)
                                                 (start #x200000) (end #x201000) (align 4)))
                                       (place c (main) (hot))
                                       (place d (far))))))))

(finish-tests "integration")
