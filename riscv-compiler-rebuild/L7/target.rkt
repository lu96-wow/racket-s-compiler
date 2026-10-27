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
         padding-bytes)

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

;; ---------------------------------------------------------------------------
;; 填充策略（这就是"芯片相关"的那部分：补什么字节）
;;
;;   data 段: 0
;;   code 段: 合法指令 —— 会顺着落下来执行, 不能留 0
;;            4 字节优先用 nop(addi x0,x0,0), 余 2 用 c.nop(c.addi x0,0)
;;            奇数字节 >>> 编不出来(没有任何 1 字节指令), 报错
;;
;; 换目标(比如用 ebreak 填空、或不允许压缩指令)只改这里。
;; ---------------------------------------------------------------------------

(define nop-word     #x00000013)   ; addi x0, x0, 0    (4 字节)
(define c-nop-word   #x0001)       ; c.addi x0, 0      (2 字节, C 扩展)

(define (padding-bytes kind n)
  (case kind
    [(code) (code-padding-bytes n)]
    [else (make-list n 0)]))

(define (code-padding-bytes n)
  (define quads (quotient n 4))
  (define rest (remainder n 4))
  (append
   (append* (for/list ([_ (in-range quads)]) (integer->bytes 4 nop-word)))
   (case rest
     [(0) '()]
     [(2) (integer->bytes 2 c-nop-word)]
     [else (error 'padding-bytes
                  "code 段里要补 ~a 字节: 剩下的 ~a 字节不是 0 也不是 2, 编不出来"
                  n rest)])))
