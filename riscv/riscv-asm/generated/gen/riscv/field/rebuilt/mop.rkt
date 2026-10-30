#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt"))

(define mop_r_t
  (combine raw:mop_r_t_30
           raw:mop_r_t_27_26
           raw:mop_r_t_21_20))
(define mop_rr_t
  (combine raw:mop_rr_t_30
           raw:mop_rr_t_27_26))

(provide
 mop_r_t
 mop_rr_t)
