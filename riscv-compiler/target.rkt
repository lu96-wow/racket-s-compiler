#lang racket
;;; target.rkt
;;;
;;; 目标配置: XLEN、扩展集。端序统一为 little。
;;;
;;; 目标不再写死。target 是显式参数:
;;;
;;;   (layout-program target program data layout-input)
;;;   (encode-layout target layout)
;;;   (encode-instruction target name operands)
;;;
;;; 不使用动态参数 / 全局 current-target。
;;;
;;; target 只放事实: 多少位、什么端序、开了哪些扩展。
;;; padding 由扩展集推导; 操作数语法、栈、ABI、reloc 都不在这里。

(require racket/string
         "../riscv-asm/generated/gen/riscv/info/extensions.rkt")

(provide (struct-out target)
         target-rv64-base
         target-rv64-all
         target-rv32-all
         integer->bytes
         padding-bytes)

(struct target (xlen extensions) #:transparent)

;; 当前默认目标: rv64 + 目前已经接入的扩展。
(define target-rv64-base
  (target 'rv64
          '(rv_i rv_m rv_a
            rv64_i rv64_m rv64_a
            rv_c rv64_c
            rv_zicsr rv_zifencei)))


;; 全扩展 profile:
;;   rv64-all = 非 rv32_* 的所有扩展
;;   rv32-all = 非 rv64_* 的所有扩展
;; 不做依赖闭包; 这是显式的扩展集合。
(define (extension-prefix? prefix e)
  (string-prefix? (symbol->string e) prefix))

(define target-rv64-all
  (target 'rv64
          (sort (filter (lambda (e) (not (extension-prefix? "rv32_" e))) extensions)
                symbol<?)))

(define target-rv32-all
  (target 'rv32
          (sort (filter (lambda (e) (not (extension-prefix? "rv64_" e))) extensions)
                symbol<?)))

;; ---------------------------------------------------------------------------
;; 目标事实
;; ---------------------------------------------------------------------------

(define (target-has-extension? target e)
  (and (memq e (target-extensions target)) #t))

(define (target-compressed? target)
  (or (target-has-extension? target 'rv_c)
      (target-has-extension? target 'rv32_c)
      (target-has-extension? target 'rv64_c)))

;; 整数 -> width 个字节(按当前 target 的端序)。
(define (integer->bytes width value)
  (define bits (* 8 width))
  (unless (<= (- (expt 2 (sub1 bits))) value (sub1 (expt 2 bits)))
    (error 'integer->bytes
           "value ~a does not fit in ~a byte(s)" value width))
  (for/list ([i (in-range width)])
    (bitwise-and (arithmetic-shift value (- (* 8 i))) #xFF)))

;; ---------------------------------------------------------------------------
;; 填充策略
;;
;;   data : 0
;;   code : 4 字节 nop; 余 2 字节只在当前 target 有 C 扩展时用 c.nop
;;          奇数字节报错(没有任何 1 字节指令)
;; ---------------------------------------------------------------------------

(define nop-word     #x00000013)   ; addi x0, x0, 0
(define c-nop-word   #x0001)       ; c.addi x0, 0

(define (padding-bytes target kind n)
  (case kind
    [(code) (code-padding-bytes target n)]
    [(data) (make-list n 0)]
    [else (error 'padding-bytes "unknown segment kind: ~a" kind)]))

(define (code-padding-bytes target n)
  (define quads (quotient n 4))
  (define rest (remainder n 4))
  (append
   (append* (for/list ([_ (in-range quads)]) (integer->bytes 4 nop-word)))
   (case rest
     [(0) '()]
     [(2)
      (unless (target-compressed? target)
        (error 'padding-bytes
               "code 段需要补 2 字节, 但当前 target 没有 C 扩展: ~a"
               (target-extensions target)))
      (integer->bytes 2 c-nop-word)]
     [else
      (error 'padding-bytes
             "code 段里要补 ~a 字节: 剩下的 ~a 字节不是 0 也不是 2, 编不出来"
             n rest)])))
