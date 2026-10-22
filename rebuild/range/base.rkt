#lang racket/base

;; ============================================================
;; RISC-V 标量基础字段
;;
;; 命名尽量与 riscv-opcodes 的操作数名保持一致。
;; imm20 是 20 位逻辑值（指令位 [31:12]）；汇编层的完整地址
;; 需要先右移 12 位，转换器放在后续 operand/adapter 层。
;; ============================================================

(require "core.rkt")

;; -------- 寄存器 --------
(define rd  (make-field 'rd  (list (slice 0 4 7))))
(define rs1 (make-field 'rs1 (list (slice 0 4 15))))
(define rs2 (make-field 'rs2 (list (slice 0 4 20))))

;; -------- I 型 --------
(define imm12
  (make-field 'imm12
              (list (slice 0 11 20))
              #:signed? #t))

;; -------- S 型 --------
(define simm12
  (make-field 'simm12
              (list (slice 0 4 7)
                    (slice 5 11 25))
              #:signed? #t))

;; -------- B 型 --------
;; 13-bit signed，bit0 恒为 0（align 2），因此不参与编码
(define bimm12
  (make-field 'bimm12
              (list (slice 1 4 8)
                    (slice 5 10 25)
                    (slice 11 11 7)
                    (slice 12 12 31))
              #:signed? #t
              #:align 2))

;; -------- J 型 --------
;; 21-bit signed，bit0 恒为 0（align 2）
(define jimm20
  (make-field 'jimm20
              (list (slice 1 10 21)
                    (slice 11 11 20)
                    (slice 12 19 12)
                    (slice 20 20 31))
              #:signed? #t
              #:align 2))

;; -------- U 型 --------
(define imm20
  (make-field 'imm20
              (list (slice 0 19 12))))

;; -------- fence --------
(define fm   (make-field 'fm   (list (slice 0 3 28))))
(define pred (make-field 'pred (list (slice 0 3 24))))
(define succ (make-field 'succ (list (slice 0 3 20))))

;; -------- 移位量 --------
(define shamtd (make-field 'shamtd (list (slice 0 5 20))))
(define shamtw (make-field 'shamtw (list (slice 0 4 20))))

;; -------- fence 标志值 --------
(define PI #b1000)
(define PO #b0100)
(define PR #b0010)
(define PW #b0001)
(define SI #b1000)
(define SO #b0100)
(define SR #b0010)
(define SW #b0001)

(define base-fields
  (list rd rs1 rs2
        imm12 simm12 bimm12 jimm20 imm20
        fm pred succ shamtd shamtw))

(provide
 rd rs1 rs2
 imm12 simm12 bimm12 jimm20 imm20
 fm pred succ shamtd shamtw
 PI PO PR PW SI SO SR SW
 base-fields)
