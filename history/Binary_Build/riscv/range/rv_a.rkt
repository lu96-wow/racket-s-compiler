#lang racket
(require "../../base.rkt"
         "helper.rkt")

;; A 扩展专用字段：aq (acquire bit 26), rl (release bit 25)
(define aq (make-bitfield-field (bit-range 0 0 26 26) 'aq 0 0))
(define rl (make-bitfield-field (bit-range 0 0 25 25) 'rl 0 0))

(provide aq rl)
