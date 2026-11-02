#lang racket
;;; amd64/loko-compatibility/lower/abi-table.rkt
;;;
;;; Loko 的 ABI 寄存器固定表。只放数据，不放分配算法。
;;;
;;; 这些集合描述 Loko target-convention，不是通用 x86-64 事实；
;;; 它们属于 loko-compatibility，不属于 compiler/amd64-help。

(provide default-available-registers
         preserved-registers)

;; Loko 可用的 GPR：scratch + preserved，去掉 %pcb/%closure/rsp。
;; 这是默认集合，不代表跨调用安全。
(define default-available-registers
  '(rax rcx rdx rsi rdi r8 r9 r10 r11 r12 r13 rbx rbp))

;; Loko target-convention 里真正跨调用保留的寄存器。
(define preserved-registers '(rbx rbp))
