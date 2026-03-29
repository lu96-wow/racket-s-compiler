#lang racket

(define rv_h-rs1
  (make-immutable-hash
    '(
      (hfence.vvma . 1)
      (hfence.gvma . 1)
      (hlv.b . 2)
      (hlv.bu . 2)
      (hlv.h . 2)
      (hlv.hu . 2)
      (hlvx.hu . 2)
      (hlv.w . 2)
      (hlvx.wu . 2)
      (hsv.b . 1)
      (hsv.h . 1)
      (hsv.w . 1)
    )))
(define rv_h-rs2
  (make-immutable-hash
    '(
      (hfence.vvma . 2)
      (hfence.gvma . 2)
      (hsv.b . 2)
      (hsv.h . 2)
      (hsv.w . 2)
    )))
(define rv_h-rd
  (make-immutable-hash
    '(
      (hlv.b . 1)
      (hlv.bu . 1)
      (hlv.h . 1)
      (hlv.hu . 1)
      (hlvx.hu . 1)
      (hlv.w . 1)
      (hlvx.wu . 1)
    )))

(define rv_h-fields '(rs1 rs2 rd ))

(provide
  rv_h-rs1
  rv_h-rs2
  rv_h-rd
  rv_h-fields)
