#lang racket/base

;; ============================================================
;; 重建表示：Zimop 字段
;; ============================================================

(require (prefix-in raw: "../raw/mop.rkt")
         "../../base.rkt")

;; mop.r.N: t = t[4] | t[3:2] | t[1:0]
(define mop_r_t
  (checked-field
   'mop_r_t
   (combine (bit 4 30)
            (bit-range 2 3 26)
            (bit-range 0 1 20))
   0 31))

;; mop.rr.N: t = t[4] | t[3:2]
(define mop_rr_t
  (checked-field
   'mop_rr_t
   (combine (bit 4 30)
            (bit-range 2 3 26))
   0 31))

(provide mop_r_t
         mop_rr_t)
