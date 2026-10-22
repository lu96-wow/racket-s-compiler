#lang racket/base

(require "struct.rkt")

;; ============================================================
;; 元数据查询
;; ============================================================

(define (find-instruction-info infos name)
  (for/first ([info (in-list infos)]
              #:when (equal? (instruction-info-name info) name))
    info))

(define (info-param-count info)
  (length (instruction-info-operands info)))

(define (info-raw-param-count info)
  (length (instruction-info-raw-operands info)))

(define (info-operands info)
  (instruction-info-operands info))

(define (info-raw-operands info)
  (instruction-info-raw-operands info))

(define (info-asm-format info)
  (instruction-info-asm info))

(define (info-width info)
  (instruction-info-width info))

(define (info-fixed-fields info)
  (instruction-info-fixed-fields info))

(define (info-aliases info)
  (instruction-info-aliases info))

(provide find-instruction-info
         info-param-count
         info-raw-param-count
         info-operands
         info-raw-operands
         info-asm-format
         info-width
         info-fixed-fields
         info-aliases)
