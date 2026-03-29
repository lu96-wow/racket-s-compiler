#lang racket

(define rv_d_zfa-rd
  (make-immutable-hash
    '(
      (fli.d . 1)
      (fminm.d . 1)
      (fmaxm.d . 1)
      (fround.d . 1)
      (froundnx.d . 1)
      (fcvtmod.w.d . 1)
      (fleq.d . 1)
      (fltq.d . 1)
    )))
(define rv_d_zfa-rs1
  (make-immutable-hash
    '(
      (fli.d . 2)
      (fminm.d . 2)
      (fmaxm.d . 2)
      (fround.d . 2)
      (froundnx.d . 2)
      (fcvtmod.w.d . 2)
      (fleq.d . 2)
      (fltq.d . 2)
    )))
(define rv_d_zfa-rs2
  (make-immutable-hash
    '(
      (fminm.d . 3)
      (fmaxm.d . 3)
      (fleq.d . 3)
      (fltq.d . 3)
    )))
(define rv_d_zfa-rm
  (make-immutable-hash
    '(
      (fround.d . 3)
      (froundnx.d . 3)
    )))

(define rv_d_zfa-fields '(rd rs1 rs2 rm ))

(provide
  rv_d_zfa-rd
  rv_d_zfa-rs1
  rv_d_zfa-rs2
  rv_d_zfa-rm
  rv_d_zfa-fields)
