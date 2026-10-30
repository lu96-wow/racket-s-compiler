#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt"))

(define c_uimm7
  (combine raw:c_uimm7lo
           raw:c_uimm7hi))
(define c_uimm8
  (combine raw:c_uimm8lo
           raw:c_uimm8hi))
(define c_uimm9
  (combine raw:c_uimm9lo
           raw:c_uimm9hi))
(define c_imm6
  (combine raw:c_imm6lo
           raw:c_imm6hi))
(define c_nzimm6
  (combine raw:c_nzimm6lo
           raw:c_nzimm6hi))
(define c_nzimm10
  (combine raw:c_nzimm10lo
           raw:c_nzimm10hi))
(define c_nzimm18
  (combine raw:c_nzimm18lo
           raw:c_nzimm18hi))
(define c_bimm9
  (combine raw:c_bimm9lo
           raw:c_bimm9hi))
(define c_nzuimm6
  (combine raw:c_nzuimm6lo
           raw:c_nzuimm6hi))
(define c_uimm8sp
  (combine raw:c_uimm8splo
           raw:c_uimm8sphi))
(define c_uimm9sp
  (combine raw:c_uimm9splo
           raw:c_uimm9sphi))
(define c_uimm10sp
  (combine raw:c_uimm10splo
           raw:c_uimm10sphi))

(provide
 c_uimm7
 c_uimm8
 c_uimm9
 c_imm6
 c_nzimm6
 c_nzimm10
 c_nzimm18
 c_bimm9
 c_nzuimm6
 c_uimm8sp
 c_uimm9sp
 c_uimm10sp)
