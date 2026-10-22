#lang racket/base

;; ============================================================
;; A 扩展字段
;; ============================================================

(require "core.rkt")

(define aq (make-field 'aq (list (slice 0 0 26))))
(define rl (make-field 'rl (list (slice 0 0 25))))

(define a-fields (list aq rl))

(provide aq rl a-fields)
