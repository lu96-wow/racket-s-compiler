#lang racket
;;; amd64/amd64-help/size.rkt
;;;
;;; 指令长度计算的统一入口（help 层）。
;;;
;;; 输入是一条完整的 instruction s-expression，输出字节数。
;;; 不生成指令、不检查跳转范围、不编码；只回答“这条形式占多少字节”。
;;;
;;; 实现仍然由 amd64-asm 的 resolved-plan 决定：尺寸和 encode 共用同一个
;;; plan，所以这里不维护第二张 size 表。数据和位置 item（label/align/pad
;;; /bytes/fill/value/reserve）不属于指令，它们的尺寸仍由 layout 的
;;; item-size 负责。

(require "../amd64-asm/shape.rkt"
         "../amd64-asm/target.rkt"
         (only-in "../amd64-asm/insn.rkt" instruction-size))

(provide (rename-out [help-instruction-size instruction-size])
         instructions-size)

(define (help-instruction-size insn #:target [target target-amd64])
  (unless (form? insn)
    (error 'instruction-size "expected an instruction form: ~e" insn))
  (instruction-size target (car insn) (cdr insn)))

(define (instructions-size insns #:target [target target-amd64])
  (for/sum ([insn (in-list insns)])
    (help-instruction-size insn #:target target)))
