#lang racket
;;; L7/target.rkt
;;;
;;; 目标常量。**端序在整个流水线里只出现在这一个文件**:
;;; D1 只交出"宽度 + 值", L5 只量尺寸, 到这里才变成字节序。
;;;
;;; 换目标(rv32 / 大端)只改这里。

(provide target-word-size
         target-endianness
         target-extensions
         integer->bytes
         code-padding-bytes)

(define target-word-size 64)

(define target-endianness 'little)

;; 目标 ISA 子集: 这个集合同时喂给 riscv-asm 的查表(它负责编码和所有位域检查)
(define target-extensions
  '(rv_i rv_m rv_a
    rv64_i rv64_m rv64_a
    rv_c rv64_c))

;; 整数 -> width 个字节(按目标端序)。值必须能放进 width 个字节。
(define (integer->bytes width value)
  (define bits (* 8 width))
  (unless (<= (- (expt 2 (sub1 bits))) value (sub1 (expt 2 bits)))
    (error 'integer->bytes
           "value ~a does not fit in ~a byte(s)" value width))
  (define bs
    (for/list ([i (in-range width)])
      (bitwise-and (arithmetic-shift value (- (* 8 i))) #xFF)))
  (cond
    [(eq? target-endianness 'little) bs]
    [(eq? target-endianness 'big) (reverse bs)]
    [else (error 'integer->bytes "unknown endianness: ~a" target-endianness)]))

;; code 段里对齐补出来的字节必须是合法指令(会顺着落下来执行),
;; 所以 code 用 nop 平铺, 其余用 0。
(define (code-padding-bytes n)
  (unless (zero? (modulo n 4))
    (error 'code-padding-bytes
           "code 段里的对齐补出了 ~a 字节(不是 4 的倍数), 编不出来" n))
  (append* (for/list ([_ (in-range (quotient n 4))]) (integer->bytes 4 #x00000013))))
