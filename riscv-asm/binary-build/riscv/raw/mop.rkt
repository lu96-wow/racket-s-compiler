#lang racket/base

;; ============================================================
;; 原始表示：Zimop 字段
;;
;; mop.r.N / mop.rr.N 的 t 字段被拆成多个不连续片段。
;; ============================================================

(require "../../base.rkt")

(define mop_r_t_30
  (bit 4 30))

(define mop_r_t_27_26
  (bit-range 2 3 26))

(define mop_r_t_21_20
  (bit-range 0 1 20))

(define mop_rr_t_30
  (bit 4 30))

(define mop_rr_t_27_26
  (bit-range 2 3 26))

(provide mop_r_t_30
         mop_r_t_27_26
         mop_r_t_21_20
         mop_rr_t_30
         mop_rr_t_27_26)
