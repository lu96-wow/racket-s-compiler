#lang racket

(define rv_q_zfa-rd
  (make-immutable-hash
    '(
      (fli.q . 1)
      (fminm.q . 1)
      (fmaxm.q . 1)
      (fround.q . 1)
      (froundnx.q . 1)
      (fleq.q . 1)
      (fltq.q . 1)
    )))
(define rv_q_zfa-rs1
  (make-immutable-hash
    '(
      (fli.q . 2)
      (fminm.q . 2)
      (fmaxm.q . 2)
      (fround.q . 2)
      (froundnx.q . 2)
      (fleq.q . 2)
      (fltq.q . 2)
    )))
(define rv_q_zfa-rs2
  (make-immutable-hash
    '(
      (fminm.q . 3)
      (fmaxm.q . 3)
      (fleq.q . 3)
      (fltq.q . 3)
    )))
(define rv_q_zfa-rm
  (make-immutable-hash
    '(
      (fround.q . 3)
      (froundnx.q . 3)
    )))

(define rv_q_zfa-fields '(rd rs1 rs2 rm ))

(provide
  rv_q_zfa-rd
  rv_q_zfa-rs1
  rv_q_zfa-rs2
  rv_q_zfa-rm
  rv_q_zfa-fields)
