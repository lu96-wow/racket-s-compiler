#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define mop.r.N
  (make-instruction
   (list mop_r_t_30 mop_r_t_27_26 mop_r_t_21_20 rd rs1)
   (list (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.rr.N
  (make-instruction
   (list mop_rr_t_30 mop_rr_t_27_26 rd rs1 rs2)
   (list (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.0
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.1
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.2
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.3
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.4
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.5
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.6
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.7
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.8
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.9
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.10
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.11
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.12
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.13
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.14
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.15
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.16
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.17
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.18
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.19
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.20
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.21
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.22
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.23
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.24
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.25
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.26
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.27
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 0) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.28
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.29
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 0) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.30
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.r.31
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 21 21 1) (bit-range-fixed 20 20 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 22 25 7) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.rr.0
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.rr.1
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.rr.2
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.rr.3
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 30 30 0) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.rr.4
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.rr.5
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 0) (bit-range-fixed 26 26 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.rr.6
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 0) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mop.rr.7
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 30 30 1) (bit-range-fixed 27 27 1) (bit-range-fixed 26 26 1) (bit-range-fixed 31 31 1) (bit-range-fixed 28 29 0) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 mop.r.N
 mop.rr.N
 mop.r.0
 mop.r.1
 mop.r.2
 mop.r.3
 mop.r.4
 mop.r.5
 mop.r.6
 mop.r.7
 mop.r.8
 mop.r.9
 mop.r.10
 mop.r.11
 mop.r.12
 mop.r.13
 mop.r.14
 mop.r.15
 mop.r.16
 mop.r.17
 mop.r.18
 mop.r.19
 mop.r.20
 mop.r.21
 mop.r.22
 mop.r.23
 mop.r.24
 mop.r.25
 mop.r.26
 mop.r.27
 mop.r.28
 mop.r.29
 mop.r.30
 mop.r.31
 mop.rr.0
 mop.rr.1
 mop.rr.2
 mop.rr.3
 mop.rr.4
 mop.rr.5
 mop.rr.6
 mop.rr.7)
