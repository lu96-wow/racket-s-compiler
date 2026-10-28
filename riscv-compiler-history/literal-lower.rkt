#lang racket/base

;; ============================================================
;; const 字面值 lowering
;;
;; (const dst #t)   -> (addi dst x0 15)
;; (const dst #f)   -> (addi dst x0 7)
;; (const dst 'nil) -> (addi dst x0 23)
;; (const dst 42)   -> (addi dst x0 42)
;;
;; 当前只接受 signed 12-bit 立即数。
;; 更大的整数以后用 lui/addi 或 li 展开。
;; ============================================================

(require racket/list
         "repr.rkt")

(provide lower-literals)

(define (fits-s12? n)
  (and (exact-integer? n)
       (>= n -2048)
       (<= n 2047)))

(define (lower-literals asm)
  (for/list ([item (in-list asm)])
    (cond
      [(const-form? item)
       (define encoded (literal-encode (const-value item)))
       (unless (fits-s12? encoded)
         (error 'lower-literals
                "literal ~a encodes to ~a, does not fit in 12 bits"
                (const-value item) encoded))
       (list 'addi (const-dst item) 'x0 encoded)]
      [else item])))
