#lang racket
;;; la-far-test.rkt -- 远 la：relax 升级 + 定长 + encode 补 nop
;;;
;;; 锁住：
;;;   - (la …) 够不着 2 GiB 时, relax 升成 (la-far …), 尺寸固定 40(rv64)
;;;   - 升级保留前端给的 tmp; 没给就留空槽(scratch-hole), 等寄存器那一层
;;;   - encode 强制远形式(不因 delta 变小而缩回近形式), 不足的上界用 nop 补齐
;;;   - 尺寸和 layout 说的必须一致(encode 的 size 断言)

(require rackunit
         racket/list
         "helpers.rkt"
         (only-in "../riscv-compiler/flow/flow.rkt"
                  run-flow flow-value default-flow)
         (only-in "../riscv-compiler/target.rkt" target-rv64-base target-rv32-all)
         (only-in "../riscv-compiler/layout/forms.rkt"
                  item-size la-far-form? scratch-hole? far-la-size)
         (only-in "../riscv-compiler/relax/relax.rkt" la-far-step)
         (only-in "../riscv-compiler/encode/encode.rkt" encode-layout)
         (only-in "../riscv-compiler/analyze/analyze.rkt" analyze))

(define target target-rv64-base)

;; ---------------------------------------------------------------------------
;; 形式 / 尺寸
;; ---------------------------------------------------------------------------

(check-equal? (far-la-size target) 40)                     ; 4 + 32(li 最坏) + 4
(check-equal? (far-la-size target-rv32-all) 16)            ; 4 +  8(li 最坏) + 4

(check-true (la-far-form? '(la-far x10 (d t))))
(check-true (la-far-form? '(la-far x10 x5 (d t))))
(check-false (la-far-form? '(la-far x10)))                 ; 缺链
(check-equal? (item-size target '(la-far x10 (d t))) 40)
(check-equal? (item-size target '(la-far x10 x5 (d t))) 40)

;; 空槽: (la-far rd 链) 缺 tmp
(check-true (scratch-hole? '(la-far x10 (d t))))
(check-false (scratch-hole? '(la-far x10 x5 (d t))))

;; ---------------------------------------------------------------------------
;; relax 的升级
;; ---------------------------------------------------------------------------

(check-equal? (la-far-step '(la x10 (d t))) '(la-far x10 (d t)))
;; 前端给了 tmp 就保留
(check-equal? (la-far-step '(la x10 x5 (d t))) '(la-far x10 x5 (d t)))
;; 不是 la 就不动
(check-false (la-far-step '(la-far x10 x5 (d t))))

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

;; 近形式够不着 -> 升成 (la-far x10 (far-data)), 并留下空槽
(define relaxed
  (flow-value (run '((label main) (la x10 (far-data)) (jalr x0 ra 0))
                   '(expand-data flatten analyze dce relax))
              'measured-layout))

(check-equal? (map car (cdr (assoc 'requests relaxed))) '(scratch-hole))
(check-equal? (list-ref (cadddr (car (cdr (assoc 'requests relaxed)))) 0) 'la-far)

;; ---------------------------------------------------------------------------
;; encode: 强制远形式 + 补 nop 到固定尺寸
;; ---------------------------------------------------------------------------

(define (far-la-item-layout item)
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
        (cons 'requests '())
        (cons 'problems '())))

(define bytes (build-bytes (encode-layout target (far-la-item-layout '(la-far x10 x5 (far-data)))) 'c))

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

;; delta 很小也照样用远形式(尺寸稳定), 40 字节不变
(define small
  (let* ([l (far-la-item-layout '(la-far x10 x5 (main)))]
         [segs (cdr (assoc 'segments l))])
    l))
(check-equal? (build-size (encode-layout target small) 'c) 40)

;; tmp 不能是 rd
(check-exn exn:fail?
           (lambda () (encode-layout target (far-la-item-layout '(la-far x10 x10 (far-data))))))

;; 空槽编不出来
(check-exn exn:fail?
           (lambda () (encode-layout target (far-la-item-layout '(la-far x10 (far-data))))))

(finish-tests "la-far")
