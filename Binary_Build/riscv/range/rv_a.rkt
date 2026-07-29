#lang racket
(require "../../base.rkt")

;; A 扩展专用字段：aq (acquire bit 26), rl (release bit 25)
(define aq (bit-range 0 26))
(define rl (bit-range 0 25))

(provide aq rl)
