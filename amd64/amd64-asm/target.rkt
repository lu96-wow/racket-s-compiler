#lang racket
;;; amd64/amd64-asm/target.rkt
;;;
;;; amd64 目标事实。第一版只支持 64 位，端序 little。

(provide (struct-out target)
         target-amd64
         target-64?
         integer->bytes
         padding-bytes)

;; MODE 是指令选择用的地址/操作数模式(16/32/64)。当前编码器只接 64。
;; 字段只留真正被读的: arch 用于报错, mode 用于 target-64?。
(struct target (arch mode) #:transparent)

(define target-amd64 (target 'amd64 64))

(define (target-64? target)
  (and (target? target) (= 64 (target-mode target))))

;; 返回 little-endian 的**字节串**（不是 list）：唯一调用方是 encode 的
;; (value 宽度 …)，直接 emit 到预分配的缓冲里。
(define (integer->bytes width value)
  (define bits (* 8 width))
  ;; 允许有符号负数和完整无符号上界，例如 width=1 时 -128..255。
  (unless (<= (- (expt 2 (sub1 bits))) value (sub1 (expt 2 bits)))
    (error 'integer->bytes "value ~a does not fit in ~a byte(s)" value width))
  (define out (make-bytes width))
  (for ([i (in-range width)])
    (bytes-set! out i (bitwise-and (arithmetic-shift value (- (* 8 i))) #xFF)))
  out)

;; 段内填充：code 用 1 字节 NOP（任意长度都合法），data 用 0。
;; 与 target 无关（两种段在 16/32/64 位模式下都是这个规则）。
(define (padding-bytes kind n)
  (case kind
    [(code) (make-bytes n #x90)]
    [(data) (make-bytes n 0)]
    [else (error 'padding-bytes "unknown segment kind: ~e" kind)]))
