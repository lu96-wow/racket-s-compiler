#lang racket/base

;; ============================================================
;; 重建表示：向量扩展字段
;; ============================================================

(require (prefix-in raw: "../raw/vector.rkt")
         "../../base.rkt")

;; vror.vi: zimm6 = zimm[4:0] + zimm[5]
(define zimm6
  (combine raw:zimm6lo
           raw:zimm6hi))

(provide zimm6)
