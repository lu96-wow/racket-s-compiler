#lang racket

;; 转发文件：聚合所有 range 模块，统一对外提供
(require "range/base.rkt"
         "range/rv_a.rkt")

(provide (all-from-out "range/base.rkt")
         (all-from-out "range/rv_a.rkt"))
