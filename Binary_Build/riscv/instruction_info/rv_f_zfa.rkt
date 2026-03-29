#lang racket

(define rv_f_zfa-rd
  (make-immutable-hash
    '(
      (fli.s . 1)
      (fminm.s . 1)
      (fmaxm.s . 1)
      (fround.s . 1)
      (froundnx.s . 1)
      (fleq.s . 1)
      (fltq.s . 1)
    )))
(define rv_f_zfa-rs1
  (make-immutable-hash
    '(
      (fli.s . 2)
      (fminm.s . 2)
      (fmaxm.s . 2)
      (fround.s . 2)
      (froundnx.s . 2)
      (fleq.s . 2)
      (fltq.s . 2)
    )))
(define rv_f_zfa-rs2
  (make-immutable-hash
    '(
      (fminm.s . 3)
      (fmaxm.s . 3)
      (fleq.s . 3)
      (fltq.s . 3)
    )))
(define rv_f_zfa-rm
  (make-immutable-hash
    '(
      (fround.s . 3)
      (froundnx.s . 3)
    )))

(define rv_f_zfa-fields '(rd rs1 rs2 rm ))

(provide
  rv_f_zfa-rd
  rv_f_zfa-rs1
  rv_f_zfa-rs2
  rv_f_zfa-rm
  rv_f_zfa-fields)
