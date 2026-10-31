#lang racket
;;; amd64/target.rkt
;;;
;;; amd64 目标事实。第一版只支持 64 位，端序 little。

(provide (struct-out target)
         target-amd64
         integer->bytes
         padding-bytes)

(struct target (arch pointer-width features) #:transparent)

(define target-amd64 (target 'amd64 64 '()))

(define (integer->bytes width value)
  (define bits (* 8 width))
  ;; 允许有符号负数和完整无符号上界，例如 width=1 时 -128..255。
  (unless (<= (- (expt 2 (sub1 bits))) value (sub1 (expt 2 bits)))
    (error 'integer->bytes "value ~a does not fit in ~a byte(s)" value width))
  (for/list ([i (in-range width)])
    (bitwise-and (arithmetic-shift value (- (* 8 i))) #xFF)))

(define (padding-bytes target kind n)
  (case kind
    [(code) (make-list n #x90)]         ; 1-byte NOP, 任意长度都合法
    [(data) (make-list n 0)]
    [else (error 'padding-bytes "unknown segment kind: ~e" kind)]))
