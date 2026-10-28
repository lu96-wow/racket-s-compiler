#lang racket
;;; encode/syntax/direct.rkt
;;;
;;; 不能表达成"第几个操作数放到第几个参数"的指令。
;;;
;;; 典型:
;;;   fence / fence.tso 的 fm/rs1/rd 是固定/保留字段, 不暴露给源码;
;;;   fence 有 0/2 两种操作数; fence.tso 固定 0 个。
;;;
;;; direct plan 的 build 直接产生 riscv-asm 函数的参数列表。
;;; 它不是普通 order plan 的替代品: 只有无法用位置表表达的才放这里。

(provide direct-plan?
         direct-plan-arities
         direct-plan-build
         direct-plan-of
         direct-plan-names)

(struct direct-plan (arities build) #:transparent)

;; i=8, o=4, r=2, w=1; 只接受 i,o,r,w 的规范顺序, 不接受 wr / rwx / 空串。
(define (fence-mode-symbol-value x)
  (define s (symbol->string x))
  (when (zero? (string-length s))
    (error 'encode-instruction "fence pred/succ 不能为空"))
  (let loop ([chars (string->list s)] [last-bit 16] [mask 0])
    (cond
      [(null? chars) mask]
      [else
       (define bit
         (case (car chars)
           [(#\i) 8]
           [(#\o) 4]
           [(#\r) 2]
           [(#\w) 1]
           [else #f]))
       (unless (and bit (< bit last-bit))
         (error 'encode-instruction
                "fence pred/succ 只能包含 i,o,r,w，且按这个顺序、不能重复: ~a" x))
       (loop (cdr chars) bit (bitwise-ior mask bit))])))

(define (fence-mode-value x)
  (cond
    [(eqv? x 0) 0]                       ; 空集; LLVM 也接受 fence 0, 0
    [(symbol? x) (fence-mode-symbol-value x)]
    [else
     (error 'encode-instruction
            "fence pred/succ 必须是 rw / iorw 这样的符号或 0: ~e" x)]))

(define (fence-args operands)
  (cond
    ;; GAS/LLVM 的 `fence` 无操作数别名 = fence iorw, iorw
    [(null? operands) (list 0 15 15 0 0)]
    [else
     (define pred (fence-mode-value (car operands)))
     (define succ (fence-mode-value (cadr operands)))
     (list 0 pred succ 0 0)]))            ; fm pred succ rs1 rd

(define (fence-tso-args _operands)
  (list 0 0))                             ; rs1 rd; fm/pred/succ 由指令固定

(define (fence-i-args _operands)
  (list 0 0 0))                           ; imm12 rs1 rd 全部为 0

(define direct-plans
  (hash
   ;; fence 接受 2 个操作数(显式 pred/succ)或 0 个(GAS/LLVM 的完整 fence 别名)
   'fence     (direct-plan '(2 0) fence-args)
   'fence.tso (direct-plan '(0) fence-tso-args)
   'fence.i   (direct-plan '(0) fence-i-args)))

(define (direct-plan-of name)
  (and (symbol? name) (hash-ref direct-plans name #f)))

(define (direct-plan-names)
  (sort (hash-keys direct-plans) symbol<?))
