#lang racket
;;; encode/syntax/operand-kind.rkt
;;;
;;; 操作数种类 -> 值。
;;;
;;; order.rkt 的位置表里, 整数还是默认的 "GPR 或整数";
;;; 需要不同解释时写成 (kind position):
;;;
;;;   (csr 2)     第二个 s-exp 操作数是 CSR 名/编号
;;;   (zimm5 2)   第二个 s-exp 操作数是 5 位无符号立即数
;;;
;;; 更细的种类 (fpr / vreg / rm / vm / nf / ...) 都从这里长, 不散到 insn.rkt。

(require "operand.rkt"
         "csr.rkt")

(provide operand-kind-value)

(define (operand-kind-value kind v)
  (case kind
    [(plain gpr) (operand-value v)]
    [(csr) (csr-value v)]
    [(zimm5)
     (unless (exact-integer? v)
       (error 'encode-instruction "zimm5 must be an integer: ~e" v))
     v]
    [else (error 'encode-instruction "unknown operand kind: ~a" kind)]))
