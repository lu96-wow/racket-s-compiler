#lang racket/base

;; ============================================================
;; instruction_info 的 size 一致性测试
;;
;; size 必须等于 width / 8，且 width 只能是 16 或 32。
;; ============================================================

(require rackunit
         racket/list
         "../generated/lib/riscv/instruction_info/struct.rkt"
         "../generated/lib/riscv/instruction_info/query.rkt"
         "../generated/lib/riscv/instruction_info/lookup.rkt")

(for ([ext (in-list (instruction-info-extensions))])
  (for ([info (in-list (extension-instruction-info ext))])
    (define name (instruction-info-name info))
    (define width (info-width info))
    (check-not-false (memv width '(16 32))
                     (format "~a/~a: width ~a" ext name width))
    (check-equal? (info-size info) (quotient width 8)
                  (format "~a/~a: size" ext name))))
