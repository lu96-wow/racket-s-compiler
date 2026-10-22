#lang racket/base

;; ============================================================
;; V 扩展字段
;;
;; 注意：vs3 是 store 的数据源，位于 rd 的位置 [11:7]，
;; 不是 rs2 的位置。旧实现把 vs3 直接别名到 vs2，会与
;; store 指令的 [24:20] 固定位重叠，这里必须分开。
;; ============================================================

(require "core.rkt")

(define vd  (make-field 'vd  (list (slice 0 4 7))))
(define vs1 (make-field 'vs1 (list (slice 0 4 15))))
(define vs2 (make-field 'vs2 (list (slice 0 4 20))))
(define vs3 (make-field 'vs3 (list (slice 0 4 7)))) ; store 数据源

(define vm (make-field 'vm (list (slice 0 0 25))))
(define nf (make-field 'nf (list (slice 0 2 29))))

(define simm5
  (make-field 'simm5
              (list (slice 0 4 15))
              #:signed? #t))

(define zimm5
  (make-field 'zimm5 (list (slice 0 4 15))))

(define zimm10
  (make-field 'zimm10 (list (slice 0 9 20))))

(define zimm11
  (make-field 'zimm11 (list (slice 0 10 20))))

(define v-fields
  (list vd vs1 vs2 vs3 vm nf simm5 zimm5 zimm10 zimm11))

(provide vd vs1 vs2 vs3 vm nf simm5 zimm5 zimm10 zimm11 v-fields)
