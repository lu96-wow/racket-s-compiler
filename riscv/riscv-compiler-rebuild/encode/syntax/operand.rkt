#lang racket
;;; encode/syntax/operand.rkt
;;;
;;; 一个 s-exp 操作数值 -> riscv-asm 参数字面量。
;;;
;;; 现在只有两种:
;;;   整数          原样交给 riscv-asm 做位域检查
;;;   GPR 名字      通过 riscv-help/registers.rkt 转成 0..31
;;;
;;; FPR / VREG / CSR / rm 等更细的 operand-kind 会在这里继续拆分,
;;; 而不是散到 insn.rkt 或各个 direct form 里。

(require "../../../riscv-help/registers.rkt")

(provide operand-value)

(define (operand-value v)
  (cond
    [(exact-integer? v) v]
    [(register->number v) => values]
    [else (error 'encode-instruction "not a register or integer: ~e" v)]))
