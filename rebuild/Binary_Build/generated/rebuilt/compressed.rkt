#lang racket/base

;; ============================================================
;; 重建表示：压缩指令字段
;;
;; 原始 token 在 raw/compressed.rkt 中各自独立存在；这里通过
;; combine 明确表达“哪些 raw token 组成一个逻辑操作数”。
;; ============================================================

(require (prefix-in raw: "../raw/compressed.rkt")
         "../../base.rkt")

;; C.LW / C.SW / C.FLW / C.FSW
(define c_uimm7
  (combine raw:c_uimm7lo
           raw:c_uimm7hi))

;; C.LD / C.SD / C.FLD / C.FSD
(define c_uimm8
  (combine raw:c_uimm8lo
           raw:c_uimm8hi))

;; C.LDSP / C.SDSP / C.FLDSP / C.FSDSP
(define c_uimm9
  (combine raw:c_uimm9lo
           raw:c_uimm9hi))

;; C.ADDI / C.LI
(define c_imm6
  (combine raw:c_imm6lo
           raw:c_imm6hi))

;; C.ADDI / C.NOP
(define c_nzimm6
  (combine raw:c_nzimm6lo
           raw:c_nzimm6hi))

;; C.ADDI16SP
(define c_nzimm10
  (combine raw:c_nzimm10lo
           raw:c_nzimm10hi))

;; C.LUI
(define c_nzimm18
  (combine raw:c_nzimm18lo
           raw:c_nzimm18hi))

;; C.BEQZ / C.BNEZ
(define c_bimm9
  (combine raw:c_bimm9lo
           raw:c_bimm9hi))

;; C.SLLI / C.SRLI / C.SRAI (RV64)
(define c_nzuimm6
  (combine raw:c_nzuimm6lo
           raw:c_nzuimm6hi))

;; C.LWSP / C.FLWSP
(define c_uimm8sp
  (combine raw:c_uimm8splo
           raw:c_uimm8sphi))

;; C.LDSP / C.FLDSP
(define c_uimm9sp
  (combine raw:c_uimm9splo
           raw:c_uimm9sphi))

;; 未在当前已批准扩展中使用
(define c_uimm10sp
  (combine raw:c_uimm10splo
           raw:c_uimm10sphi))

(provide c_uimm7
         c_uimm8
         c_uimm9
         c_imm6
         c_nzimm6
         c_nzimm10
         c_nzimm18
         c_bimm9
         c_nzuimm6
         c_uimm8sp
         c_uimm9sp
         c_uimm10sp)
