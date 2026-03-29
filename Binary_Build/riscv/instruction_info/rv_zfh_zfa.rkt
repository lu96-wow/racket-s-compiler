#lang racket

(define rv_zfh_zfa-rd
  (make-immutable-hash
    '(
      (fli.h . 1)
      (fminm.h . 1)
      (fmaxm.h . 1)
      (fround.h . 1)
      (froundnx.h . 1)
      (fleq.h . 1)
      (fltq.h . 1)
    )))
(define rv_zfh_zfa-rs1
  (make-immutable-hash
    '(
      (fli.h . 2)
      (fminm.h . 2)
      (fmaxm.h . 2)
      (fround.h . 2)
      (froundnx.h . 2)
      (fleq.h . 2)
      (fltq.h . 2)
    )))
(define rv_zfh_zfa-rs2
  (make-immutable-hash
    '(
      (fminm.h . 3)
      (fmaxm.h . 3)
      (fleq.h . 3)
      (fltq.h . 3)
    )))
(define rv_zfh_zfa-rm
  (make-immutable-hash
    '(
      (fround.h . 3)
      (froundnx.h . 3)
    )))

(define rv_zfh_zfa-fields '(rd rs1 rs2 rm ))

(provide
  rv_zfh_zfa-rd
  rv_zfh_zfa-rs1
  rv_zfh_zfa-rs2
  rv_zfh_zfa-rm
  rv_zfh_zfa-fields)
