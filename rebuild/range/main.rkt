#lang racket/base

;; ============================================================
;; range 聚合入口
;; ============================================================

(require "core.rkt"
         "base.rkt"
         "a.rkt"
         "v.rkt")

(provide (all-from-out "core.rkt")
         (all-from-out "base.rkt")
         (all-from-out "a.rkt")
         (all-from-out "v.rkt")
         range-fields
         range-field-table)

;; 所有已知字段，供上层按名字查找
(define range-fields
  (append base-fields a-fields v-fields))

(define range-field-table
  (make-immutable-hash
   (for/list ([f (in-list range-fields)])
     (cons (field-name f) f))))
