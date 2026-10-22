#lang racket/base

(require rackunit
         (prefix-in bit: "../bit.rkt")
         (prefix-in raw: "../raw/scalar.rkt")
         (prefix-in rebuilt: "../rebuilt/scalar.rkt")
         (prefix-in core: "../core.rkt")
         (prefix-in core-field: "../base.rkt"))

;; ------------------------------------------------------------
;; bit / bit-range / fixed
;; ------------------------------------------------------------

(check-equal? ((bit:bit-range 0 4 7) #x1F) #xF80)
(check-equal? ((bit:bit-range 5 11 25) -1) #xFE000000)
(check-equal? ((bit:bit-range 0 11 20) #xABC) #xABC00000)
(check-equal? ((bit:bit-range-fixed 0 6 #x13) 0) #x13)

;; ------------------------------------------------------------
;; make-instruction
;; ------------------------------------------------------------

(define raw-addi
  (bit:make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit:bit-range-fixed 12 14 0)
         (bit:bit-range-fixed 0 6 #x13))))

(check-equal? (raw-addi 1 2 3) #x00310093)
(check-exn exn:fail?
           (lambda () (raw-addi 1 2)))

;; ------------------------------------------------------------
;; raw / rebuilt 字段与 core 对照
;; ------------------------------------------------------------

;; S 型立即数：rebuilt 的 simm12 必须等于 core 中完整 S 型字段的结果
(for ([v (in-range -2048 2048)])
  (check-equal? (rebuilt:simm12 v)
                (core:encode-field core-field:simm12 v)
                (format "simm12 ~a" v)))

;; B 型偏移：13 位有符号，bit0 恒为 0
(for ([v (in-range -4096 4095 2)])
  (check-equal? (rebuilt:bimm12 v)
                (core:encode-field core-field:bimm12 v)
                (format "bimm12 ~a" v)))

;; J 型偏移
(for ([v '(-1048576 -4 -2 0 2 4 1048574)])
  (check-equal? (raw:jimm20 v)
                (core:encode-field core-field:jimm20 v)
                (format "jimm20 ~a" v)))

;; U 型立即数
(for ([v '(0 1 2 1048575)])
  (check-equal? (raw:imm20 v)
                (core:encode-field core-field:imm20 v)
                (format "imm20 ~a" v)))

;; I 型立即数
(for ([v '(-2048 -1 0 1 2047)])
  (check-equal? (raw:imm12 v)
                (core:encode-field core-field:imm12 v)
                (format "imm12 ~a" v)))

;; 移位量
(for ([v '(0 1 31 32 63)])
  (check-equal? (raw:shamtd v)
                (core:encode-field core-field:shamtd v)
                (format "shamtd ~a" v)))

(for ([v '(0 1 15 31)])
  (check-equal? (raw:shamtw v)
                (core:encode-field core-field:shamtw v)
                (format "shamtw ~a" v)))

;; ------------------------------------------------------------
;; 原始片段组合关系
;; ------------------------------------------------------------

;; imm12hi + imm12lo 是 S 型布局，不是 I 型布局
(for ([v '(-2048 -1 0 1 2047)])
  (check-equal? (bitwise-ior (raw:imm12hi v)
                             (raw:imm12lo v))
                (core:encode-field core-field:simm12 v)
                (format "imm12hi+lo ~a" v)))

;; ------------------------------------------------------------
;; 输出
;; ------------------------------------------------------------

(displayln "scalar field tests passed")
