#lang racket/base

;; ============================================================
;; 原始表示：Zimop 字段
;;
;; mop.r.N / mop.rr.N 的 t 字段被拆成多个不连续片段。
;; 每个片段函数都接收完整 5-bit N，并检查 0..31。
;; ============================================================

(require "../../base.rkt")

(define mop_r_t_30
  (checked-field 'mop_r_t_30 (bit 4 30) 0 31))

(define mop_r_t_27_26
  (checked-field 'mop_r_t_27_26 (bit-range 2 3 26) 0 31))

(define mop_r_t_21_20
  (checked-field 'mop_r_t_21_20 (bit-range 0 1 20) 0 31))

(define mop_rr_t_30
  (checked-field 'mop_rr_t_30 (bit 4 30) 0 31))

(define mop_rr_t_27_26
  (checked-field 'mop_rr_t_27_26 (bit-range 2 3 26) 0 31))

(provide mop_r_t_30
         mop_r_t_27_26
         mop_r_t_21_20
         mop_rr_t_30
         mop_rr_t_27_26)
