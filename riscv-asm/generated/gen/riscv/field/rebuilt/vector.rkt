#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt"))

(define zimm6
  (combine raw:zimm6lo
           raw:zimm6hi))

(provide
 zimm6)
