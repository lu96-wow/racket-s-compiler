#lang racket
;;; code/validate.rkt
;;;
;;; backend 入口的纯检查：不改代码、不建 CFG。
;;;
;;; 目前只做一件事：显式控制转移的 arity / 形状。
;;;   (jal g)                     -> 拒绝: link 是前端的决定，不猜 ABI
;;;   (branch-jal beq a b L)      -> 固定 arity
;;;   (branch-auipc-jalr ...)     -> 固定 arity
;;;   (jump-auipc-jalr ...)       -> 固定 arity
;;;   (la-pcrel / la-pcrel-li-add) -> 固定 arity

(require "insn.rkt"
         "../code.rkt")

(provide validate-code)

(define (validate-code c)
  (unless (code? c)
    (error 'validate "expected code (blocks + falls): ~e" c))
  (for ([b (in-list (code-blocks c))])
    (for ([it (in-list (block-items b))])
      (check-transfer-arity! it)))
  c)
