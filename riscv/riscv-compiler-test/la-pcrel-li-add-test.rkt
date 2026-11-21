#lang racket
;;; la-pcrel-li-add-test.rkt -- 显式远 la: 形式 / 检查 / 定长 / encode 补 nop
;;;
;;; 锁住：
;;;   - 近形式 (la-pcrel …) 够不着 2 GiB 时, check 报 la-too-far; 不自动升级
;;;   - 前端显式写 (la-pcrel-li-add rd tmp 链), 尺寸固定 40(rv64)
;;;   - tmp 是必需操作数; tmp=x0 或 tmp=rd 由 check 报 problem
;;;   - encode 固定展开(不因 delta 变小而缩回近形式), 不足的上界用 nop 补齐
;;;   - 尺寸和 layout 说的必须一致(encode 的 size 断言)

(require rackunit
         racket/list
         "helpers.rkt"
         (only-in "../riscv-compiler/flow/flow.rkt"
                  run-flow flow-value default-flow)
         (only-in "../riscv-compiler/target.rkt" target-rv64-base target-rv32-all)
         (only-in "../riscv-compiler/layout/forms.rkt"
                  item-size la-pcrel-li-add-form? la-pcrel-li-add-tmp la-pcrel-li-add-size)
         (only-in "../riscv-compiler/encode/encode.rkt" encode-layout))

(define target target-rv64-base)

;; ---------------------------------------------------------------------------
;; 形式 / 尺寸
;; ---------------------------------------------------------------------------

(check-equal? (la-pcrel-li-add-size target) 40)            ; 4 + 32(li 最坏) + 4
(check-equal? (la-pcrel-li-add-size target-rv32-all) 16)   ; 4 +  8(li 最坏) + 4

;; tmp 是必需操作数: 3 项不是这个形式
(check-false (la-pcrel-li-add-form? '(la-pcrel-li-add x10 (d t))))
(check-true  (la-pcrel-li-add-form? '(la-pcrel-li-add x10 x5 (d t))))
(check-false (la-pcrel-li-add-form? '(la-pcrel-li-add x10)))  ; 缺链
(check-equal? (item-size target '(la-pcrel-li-add x10 x5 (d t))) 40)
(check-equal? (la-pcrel-li-add-tmp '(la-pcrel-li-add x10 x5 (d t))) 'x5)

;; ---------------------------------------------------------------------------
;; 端到端: 两个段相距 ~2.5 GiB
;; ---------------------------------------------------------------------------

(define spec
  '((origin #x1000)
    (segments (segment (name c) (kind code) (start #x1000) (end #x3000) (align 4))
              (segment (name far) (kind data) (start #xA0000000) (end #xA0001000) (align 8)))
    (place c (main))
    (place far (far-data))))

(define rich '((label far-data) (utf-stringz "x")))

(define (run src [flow default-flow])
  (run-flow target flow
            (list (cons 'rich-data rich)
                  (cons 'program-items src)
                  (cons 'layout-spec spec))))

;; 近形式够不着: check 报 la-too-far, 不自动升级
(define near-checked
  (flow-value (run '((label main) (la-pcrel x10 (far-data)) (jalr x0 ra 0))
                   '(expand-data flatten analyze dce layout check))
              'measured-layout))
(check-true (has-problem? near-checked 'la-too-far))

;; 前端显式写 la-pcrel-li-add: check 通过, encode 产出 40 字节
(define far-out
  (run '((label main) (la-pcrel-li-add x10 x5 (far-data)) (jalr x0 ra 0))))
(check-equal? (layout-problem-list (flow-value far-out 'bound-layout)) '())
(check-equal? (build-size (flow-value far-out 'build) 'c) 44) ; la-pcrel-li-add 40 + jalr 4

;; ---------------------------------------------------------------------------
;; encode: 固定展开 + 补 nop 到固定尺寸
;; ---------------------------------------------------------------------------

(define (la-pcrel-li-add-item-layout item)
  (list (list 'phase 'bound)
        (list 'origin #x1000)
        (cons 'segments
              (list (list 'segment
                          '(name c) '(kind code) '(start #x1000) '(end #x3000) '(align 4)
                          (cons 'items (list (list 'offset 0 (list 'label 'main))
                                             (list 'offset 0 item)))
                          (list 'size 40))))
        (cons 'anchors '())
        (cons 'symbols '((symbol (main) c 0 #x1000)
                         (symbol (far-data) far 0 #xA0000000)))
        (cons 'link (list (list 'base #x1000) (list 'symbol '(far-data) #xA0000000)))
        (cons 'provides '((far-data)))
        (cons 'problems '())))

(define bytes (build-bytes (encode-layout target (la-pcrel-li-add-item-layout '(la-pcrel-li-add x10 x5 (far-data)))) 'c))

(check-equal? (length bytes) 40)
;; auipc x10, 0 一定是第一条(delta 的基准)
(check-equal? (take bytes 4) '(#x17 #x05 #x00 #x00))
;; 一条 add 收尾: opcode 0x33, rd=x10, rs1=x10, rs2=x5
(check-equal? (list-ref bytes 16) #x33)
;; 剩下的都是 nop(0x13 0x00 0x00 0x00)
(for ([i (in-range 20 40 4)])
  (check-equal? (list (list-ref bytes i) (list-ref bytes (+ i 1))
                      (list-ref bytes (+ i 2)) (list-ref bytes (+ i 3)))
                '(#x13 #x00 #x00 #x00)))

;; delta 很小也照样用固定形式(尺寸稳定), 40 字节不变
(define small (la-pcrel-li-add-item-layout '(la-pcrel-li-add x10 x5 (main))))
(check-equal? (build-size (encode-layout target small) 'c) 40)

;; tmp 不能是 rd
(check-exn exn:fail?
           (lambda () (encode-layout target (la-pcrel-li-add-item-layout '(la-pcrel-li-add x10 x10 (far-data))))))

(finish-tests "la-pcrel-li-add")
