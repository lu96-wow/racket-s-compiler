#lang racket/base

;; ============================================================
;; 寄存器表入口
;;
;; 唯一数据源在 riscv-asm/base/register.rkt。
;; 这里只做转发，保持 riscv-help 现有调用方不变。
;; ============================================================

(require "../riscv-asm/base/register.rkt")

(provide (all-from-out "../riscv-asm/base/register.rkt"))
