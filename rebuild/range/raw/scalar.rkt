#lang racket/base

;; ============================================================
;; 原始表示：标量扩展字段
;;
;; 这里的名字严格对应 riscv-opcodes 源文件里的 token。
;; 不做 hi/lo 合并，也不做语义重命名。
;;
;; 每个字段函数都接收“完整逻辑值”，只负责把自己的位放到指令字里。
;; 例如：
;;   imm12hi 接收完整 12 位值，取 [5:11] 放到指令字 [25:31]
;;   imm12lo 接收完整 12 位值，取 [0:4]  放到指令字 [7:11]
;;
;; 组合后的 simm12 由 ../rebuilt/scalar.rkt 负责。
;; ============================================================

(require "../bit.rkt")

;; -------- 通用寄存器 --------
(define rd  (bit-range 0 4 7))
(define rt  (bit-range 0 4 15))
(define rs1 (bit-range 0 4 15))
(define rs2 (bit-range 0 4 20))
(define rs3 (bit-range 0 4 27))

;; -------- 原子/内存序 --------
(define aqrl (bit-range 0 1 25))
(define aq   (bit 0 26))
(define rl   (bit 0 25))

;; -------- fence --------
(define fm   (bit-range 0 3 28))
(define pred (bit-range 0 3 24))
(define succ (bit-range 0 3 20))

;; -------- 浮点舍入模式 --------
(define rm (bit-range 0 2 12))

;; -------- U / J / I / S / B 型 --------
(define imm20 (bit-range 0 19 12))

(define jimm20
  (combine (bit-range 1 10 21)
           (bit-range 11 11 20)
           (bit-range 12 19 12)
           (bit-range 20 20 31)))

(define imm12  (bit-range 0 11 20))
(define csr    (bit-range 0 11 20))

(define imm12hi (bit-range 5 11 25))
(define imm12lo (bit-range 0 4 7))

(define bimm12hi
  (combine (bit-range 5 10 25)
           (bit-range 12 12 31)))

(define bimm12lo
  (combine (bit-range 1 4 8)
           (bit-range 11 11 7)))

;; -------- 移位量 --------
(define shamtq  (bit-range 0 6 20))
(define shamtw  (bit-range 0 4 20))
(define shamtw4 (bit-range 0 3 20))
(define shamtd  (bit-range 0 5 20))

;; -------- 小型立即数 --------
(define bs   (bit-range 0 1 30))
(define rnum (bit-range 0 3 20))
(define rc   (bit-range 0 4 25))

(define imm2 (bit-range 0 1 20))
(define imm3 (bit-range 0 2 20))
(define imm4 (bit-range 0 3 20))
(define imm5 (bit-range 0 4 20))
(define imm6 (bit-range 0 5 20))

(define zimm5 (bit-range 0 4 15))

(provide
 rd rt rs1 rs2 rs3
 aqrl aq rl
 fm pred succ
 rm
 imm20 jimm20 imm12 csr
 imm12hi imm12lo
 bimm12hi bimm12lo
 shamtq shamtw shamtw4 shamtd
 bs rnum rc
 imm2 imm3 imm4 imm5 imm6
 zimm5)
