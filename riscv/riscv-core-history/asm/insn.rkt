#lang racket
;;; asm/insn.rkt -- flat machine item 的共享事实。
;;;
;;; raw 单元（raw/raw.rkt）和 inline asm 块（asm/code.rkt）是两种封闭的
;;; machine 单元，词汇相同：
;;;   - 哪些助记符是条件分支；
;;;   - 什么算一个机器操作数（整数 / (native xN)）。
;;;
;;; 以前两边各写一份；新增一条分支指令时只改一边就会分叉。
;;; 规范化（label 解析、尺寸、错误信息）仍然留在各自的封闭单元里。

(require "../core/sexp.rkt"
         "../ir/shape.rkt")

(provide branch-mnemonics
         machine-operand?)

(define branch-mnemonics
  '(beq bne blt bge bltu bgeu))

(define (machine-operand? x)
  (or (exact-integer? x)
      (physical-register? x)))
