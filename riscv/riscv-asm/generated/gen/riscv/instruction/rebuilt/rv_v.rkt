#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/mop.rkt"))

(define vsetivli
  (make-instruction
   (list raw:zimm10 raw:zimm5 raw:rd)
   (list (bit-range-fixed 31 31 1) (bit-range-fixed 30 30 1) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 87))))
(define vsetvli
  (make-instruction
   (list raw:zimm11 raw:rs1 raw:rd)
   (list (bit-range-fixed 31 31 0) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 87))))
(define vsetvl
  (make-instruction
   (list raw:rs2 raw:rs1 raw:rd)
   (list (bit-range-fixed 31 31 1) (bit-range-fixed 25 30 0) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 87))))
(define vlm.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 28 31 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 11) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vsm.v
  (make-instruction
   (list raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 31 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 11) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 39))))
(define vle8.v
  (make-instruction
   (list raw:nf raw:vm raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vle16.v
  (make-instruction
   (list raw:nf raw:vm raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 7))))
(define vle32.v
  (make-instruction
   (list raw:nf raw:vm raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 7))))
(define vle64.v
  (make-instruction
   (list raw:nf raw:vm raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 7))))
(define vse8.v
  (make-instruction
   (list raw:nf raw:vm raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 39))))
(define vse16.v
  (make-instruction
   (list raw:nf raw:vm raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 39))))
(define vse32.v
  (make-instruction
   (list raw:nf raw:vm raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 39))))
(define vse64.v
  (make-instruction
   (list raw:nf raw:vm raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 39))))
(define vluxei8.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 1) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vluxei16.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 1) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 7))))
(define vluxei32.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 1) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 7))))
(define vluxei64.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 1) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 7))))
(define vsuxei8.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 1) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 39))))
(define vsuxei16.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 1) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 39))))
(define vsuxei32.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 1) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 39))))
(define vsuxei64.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 1) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 39))))
(define vlse8.v
  (make-instruction
   (list raw:nf raw:vm raw:rs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 2) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vlse16.v
  (make-instruction
   (list raw:nf raw:vm raw:rs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 2) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 7))))
(define vlse32.v
  (make-instruction
   (list raw:nf raw:vm raw:rs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 2) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 7))))
(define vlse64.v
  (make-instruction
   (list raw:nf raw:vm raw:rs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 2) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 7))))
(define vsse8.v
  (make-instruction
   (list raw:nf raw:vm raw:rs2 raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 2) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 39))))
(define vsse16.v
  (make-instruction
   (list raw:nf raw:vm raw:rs2 raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 2) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 39))))
(define vsse32.v
  (make-instruction
   (list raw:nf raw:vm raw:rs2 raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 2) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 39))))
(define vsse64.v
  (make-instruction
   (list raw:nf raw:vm raw:rs2 raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 2) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 39))))
(define vloxei8.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 3) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vloxei16.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 3) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 7))))
(define vloxei32.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 3) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 7))))
(define vloxei64.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 3) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 7))))
(define vsoxei8.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 3) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 39))))
(define vsoxei16.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 3) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 39))))
(define vsoxei32.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 3) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 39))))
(define vsoxei64.v
  (make-instruction
   (list raw:nf raw:vm raw:vs2 raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 3) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 39))))
(define vle8ff.v
  (make-instruction
   (list raw:nf raw:vm raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 20 24 16) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vle16ff.v
  (make-instruction
   (list raw:nf raw:vm raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 20 24 16) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 7))))
(define vle32ff.v
  (make-instruction
   (list raw:nf raw:vm raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 20 24 16) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 7))))
(define vle64ff.v
  (make-instruction
   (list raw:nf raw:vm raw:rs1 raw:vd)
   (list (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 20 24 16) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 7))))
(define vl1re8.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vl1re16.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 7))))
(define vl1re32.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 7))))
(define vl1re64.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 7))))
(define vl2re8.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vl2re16.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 7))))
(define vl2re32.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 7))))
(define vl2re64.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 7))))
(define vl4re8.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 3) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vl4re16.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 3) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 7))))
(define vl4re32.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 3) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 7))))
(define vl4re64.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 3) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 7))))
(define vl8re8.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 7) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vl8re16.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 7) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 7))))
(define vl8re32.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 7) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 7))))
(define vl8re64.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 7) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 7) (bit-range-fixed 0 6 7))))
(define vs1r.v
  (make-instruction
   (list raw:rs1 raw:vs3)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 39))))
(define vs2r.v
  (make-instruction
   (list raw:rs1 raw:vs3)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 39))))
(define vs4r.v
  (make-instruction
   (list raw:rs1 raw:vs3)
   (list (bit-range-fixed 29 31 3) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 39))))
(define vs8r.v
  (make-instruction
   (list raw:rs1 raw:vs3)
   (list (bit-range-fixed 29 31 7) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 39))))
(define vfadd.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 0) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfsub.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 2) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfmin.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 4) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfmax.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 6) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfsgnj.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 8) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfsgnjn.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 9) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfsgnjx.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 10) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfslide1up.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 14) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfslide1down.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 15) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfmv.s.f
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 16) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfmerge.vfm
  (make-instruction
   (list raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 23) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfmv.v.f
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 23) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vmfeq.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 24) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vmfle.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 25) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vmflt.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 27) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vmfne.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 28) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vmfgt.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 29) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vmfge.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 31) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfdiv.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 32) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfrdiv.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 33) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfmul.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 36) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfrsub.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 39) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfmadd.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfnmadd.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfmsub.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 42) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfnmsub.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 43) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfmacc.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 44) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfnmacc.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 45) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfmsac.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 46) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfnmsac.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 47) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfwadd.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfwsub.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 50) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfwadd.wf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 52) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfwsub.wf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 54) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfwmul.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 56) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfwmacc.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 60) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfwnmacc.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 61) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfwmsac.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 62) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfwnmsac.vf
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 63) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 87))))
(define vfadd.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 0) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfredusum.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 1) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfsub.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 2) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfredosum.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 3) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfmin.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 4) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfredmin.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 5) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfmax.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 6) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfredmax.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 7) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfsgnj.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 8) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfsgnjn.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 9) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfsgnjx.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 10) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfmv.f.s
  (make-instruction
   (list raw:vs2 raw:rd)
   (list (bit-range-fixed 26 31 16) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vmfeq.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 24) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vmfle.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 25) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vmflt.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 27) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vmfne.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 28) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfdiv.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 32) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfmul.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 36) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfmadd.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfnmadd.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfmsub.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 42) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfnmsub.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 43) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfmacc.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 44) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfnmacc.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 45) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfmsac.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 46) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfnmsac.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 47) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfcvt.xu.f.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfcvt.x.f.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 1) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfcvt.f.xu.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 2) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfcvt.f.x.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 3) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfcvt.rtz.xu.f.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 6) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfcvt.rtz.x.f.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 7) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwcvt.xu.f.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 8) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwcvt.x.f.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 9) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwcvt.f.xu.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 10) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwcvt.f.x.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 11) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwcvt.f.f.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 12) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwcvt.rtz.xu.f.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 14) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwcvt.rtz.x.f.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 15) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfncvt.xu.f.w
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 16) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfncvt.x.f.w
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 17) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfncvt.f.xu.w
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 18) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfncvt.f.x.w
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 19) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfncvt.f.f.w
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 20) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfncvt.rod.f.f.w
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 21) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfncvt.rtz.xu.f.w
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 22) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfncvt.rtz.x.f.w
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 23) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfsqrt.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 19) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfrsqrt7.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 19) (bit-range-fixed 15 19 4) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfrec7.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 19) (bit-range-fixed 15 19 5) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfclass.v
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 19) (bit-range-fixed 15 19 16) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwadd.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 48) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwredusum.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 49) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwsub.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 50) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwredosum.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 51) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwadd.wv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 52) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwsub.wv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 54) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwmul.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 56) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwmacc.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 60) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwnmacc.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 61) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwmsac.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 62) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwnmsac.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 63) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vadd.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 0) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vsub.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 2) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vrsub.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 3) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vminu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 4) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmin.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 5) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmaxu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 6) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmax.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 7) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vand.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 9) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vor.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 10) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vxor.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 11) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vrgather.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 12) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vslideup.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 14) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vslidedown.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 15) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vadc.vxm
  (make-instruction
   (list raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 16) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmadc.vxm
  (make-instruction
   (list raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 17) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmadc.vx
  (make-instruction
   (list raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 17) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vsbc.vxm
  (make-instruction
   (list raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmsbc.vxm
  (make-instruction
   (list raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 19) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmsbc.vx
  (make-instruction
   (list raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 19) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmerge.vxm
  (make-instruction
   (list raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 23) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmv.v.x
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 23) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmseq.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 24) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmsne.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 25) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmsltu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 26) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmslt.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 27) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmsleu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 28) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmsle.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 29) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmsgtu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 30) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vmsgt.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 31) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vsaddu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 32) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vsadd.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 33) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vssubu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 34) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vssub.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 35) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vsll.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 37) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vsmul.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 39) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vsrl.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vsra.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vssrl.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 42) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vssra.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 43) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vnsrl.wx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 44) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vnsra.wx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 45) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vnclipu.wx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 46) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vnclip.wx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 47) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vadd.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 0) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vsub.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 2) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vminu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 4) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmin.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 5) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmaxu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 6) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmax.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 7) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vand.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 9) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vor.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 10) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vxor.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 11) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vrgather.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 12) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vrgatherei16.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 14) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vadc.vvm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 16) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmadc.vvm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 17) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmadc.vv
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 17) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vsbc.vvm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmsbc.vvm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 19) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmsbc.vv
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 19) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmerge.vvm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 23) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmv.v.v
  (make-instruction
   (list raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 23) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmseq.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 24) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmsne.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 25) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmsltu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 26) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmslt.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 27) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmsleu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 28) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vmsle.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 29) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vsaddu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 32) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vsadd.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 33) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vssubu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 34) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vssub.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 35) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vsll.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 37) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vsmul.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 39) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vsrl.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vsra.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vssrl.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 42) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vssra.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 43) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vnsrl.wv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 44) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vnsra.wv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 45) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vnclipu.wv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 46) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vnclip.wv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 47) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vwredsumu.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 48) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vwredsum.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 49) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vadd.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 0) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vrsub.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 3) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vand.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 9) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vor.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 10) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vxor.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 11) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vrgather.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 12) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vslideup.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 14) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vslidedown.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 15) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vadc.vim
  (make-instruction
   (list raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 16) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmadc.vim
  (make-instruction
   (list raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 17) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmadc.vi
  (make-instruction
   (list raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 17) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmerge.vim
  (make-instruction
   (list raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 23) (bit-range-fixed 25 25 0) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmv.v.i
  (make-instruction
   (list raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 23) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmseq.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 24) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmsne.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 25) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmsleu.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 28) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmsle.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 29) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmsgtu.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 30) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmsgt.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 31) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vsaddu.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 32) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vsadd.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:simm5 raw:vd)
   (list (bit-range-fixed 26 31 33) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vsll.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 37) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmv1r.v
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 39) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmv2r.v
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 39) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 1) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmv4r.v
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 39) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 3) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vmv8r.v
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 39) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 7) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vsrl.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vsra.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vssrl.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 42) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vssra.vi
  (make-instruction
   (list raw:vm raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 43) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vnsrl.wi
  (make-instruction
   (list raw:vm raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 44) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vnsra.wi
  (make-instruction
   (list raw:vm raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 45) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vnclipu.wi
  (make-instruction
   (list raw:vm raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 46) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vnclip.wi
  (make-instruction
   (list raw:vm raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 47) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vredsum.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 0) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vredand.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vredor.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 2) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vredxor.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 3) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vredminu.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 4) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vredmin.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 5) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vredmaxu.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 6) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vredmax.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 7) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vaaddu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 8) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vaadd.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 9) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vasubu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 10) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vasub.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 11) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmv.x.s
  (make-instruction
   (list raw:vs2 raw:rd)
   (list (bit-range-fixed 26 31 16) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vzext.vf8
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 2) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vsext.vf8
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 3) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vzext.vf4
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 4) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vsext.vf4
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 5) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vzext.vf2
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 6) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vsext.vf2
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 7) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vcompress.vm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 23) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmandn.mm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 24) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmand.mm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 25) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmor.mm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 26) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmxor.mm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 27) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmorn.mm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 28) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmnand.mm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 29) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmnor.mm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 30) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmxnor.mm
  (make-instruction
   (list raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 31) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmsbf.m
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 20) (bit-range-fixed 15 19 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmsof.m
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 20) (bit-range-fixed 15 19 2) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmsif.m
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 20) (bit-range-fixed 15 19 3) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define viota.m
  (make-instruction
   (list raw:vm raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 20) (bit-range-fixed 15 19 16) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vid.v
  (make-instruction
   (list raw:vm raw:vd)
   (list (bit-range-fixed 26 31 20) (bit-range-fixed 20 24 0) (bit-range-fixed 15 19 17) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vcpop.m
  (make-instruction
   (list raw:vm raw:vs2 raw:rd)
   (list (bit-range-fixed 26 31 16) (bit-range-fixed 15 19 16) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vfirst.m
  (make-instruction
   (list raw:vm raw:vs2 raw:rd)
   (list (bit-range-fixed 26 31 16) (bit-range-fixed 15 19 17) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vdivu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 32) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vdiv.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 33) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vremu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 34) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vrem.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 35) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmulhu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 36) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmul.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 37) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmulhsu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 38) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmulh.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 39) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmadd.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vnmsub.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 43) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmacc.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 45) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vnmsac.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 47) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwaddu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 48) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwadd.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 49) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwsubu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 50) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwsub.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 51) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwaddu.wv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 52) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwadd.wv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 53) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwsubu.wv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 54) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwsub.wv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 55) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwmulu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 56) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwmulsu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 58) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwmul.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 59) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwmaccu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 60) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwmacc.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 61) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vwmaccsu.vv
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 63) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vaaddu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 8) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vaadd.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 9) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vasubu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 10) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vasub.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 11) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vmv.s.x
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 16) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vslide1up.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 14) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vslide1down.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 15) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vdivu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 32) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vdiv.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 33) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vremu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 34) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vrem.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 35) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vmulhu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 36) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vmul.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 37) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vmulhsu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 38) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vmulh.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 39) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vmadd.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vnmsub.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 43) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vmacc.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 45) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vnmsac.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 47) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwaddu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 48) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwadd.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 49) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwsubu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 50) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwsub.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 51) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwaddu.wx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 52) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwadd.wx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 53) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwsubu.wx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 54) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwsub.wx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 55) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwmulu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 56) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwmulsu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 58) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwmul.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 59) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwmaccu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 60) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwmacc.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 61) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwmaccus.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 62) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vwmaccsu.vx
  (make-instruction
   (list raw:vm raw:vs2 raw:rs1 raw:vd)
   (list (bit-range-fixed 26 31 63) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))

(provide
 vsetivli
 vsetvli
 vsetvl
 vlm.v
 vsm.v
 vle8.v
 vle16.v
 vle32.v
 vle64.v
 vse8.v
 vse16.v
 vse32.v
 vse64.v
 vluxei8.v
 vluxei16.v
 vluxei32.v
 vluxei64.v
 vsuxei8.v
 vsuxei16.v
 vsuxei32.v
 vsuxei64.v
 vlse8.v
 vlse16.v
 vlse32.v
 vlse64.v
 vsse8.v
 vsse16.v
 vsse32.v
 vsse64.v
 vloxei8.v
 vloxei16.v
 vloxei32.v
 vloxei64.v
 vsoxei8.v
 vsoxei16.v
 vsoxei32.v
 vsoxei64.v
 vle8ff.v
 vle16ff.v
 vle32ff.v
 vle64ff.v
 vl1re8.v
 vl1re16.v
 vl1re32.v
 vl1re64.v
 vl2re8.v
 vl2re16.v
 vl2re32.v
 vl2re64.v
 vl4re8.v
 vl4re16.v
 vl4re32.v
 vl4re64.v
 vl8re8.v
 vl8re16.v
 vl8re32.v
 vl8re64.v
 vs1r.v
 vs2r.v
 vs4r.v
 vs8r.v
 vfadd.vf
 vfsub.vf
 vfmin.vf
 vfmax.vf
 vfsgnj.vf
 vfsgnjn.vf
 vfsgnjx.vf
 vfslide1up.vf
 vfslide1down.vf
 vfmv.s.f
 vfmerge.vfm
 vfmv.v.f
 vmfeq.vf
 vmfle.vf
 vmflt.vf
 vmfne.vf
 vmfgt.vf
 vmfge.vf
 vfdiv.vf
 vfrdiv.vf
 vfmul.vf
 vfrsub.vf
 vfmadd.vf
 vfnmadd.vf
 vfmsub.vf
 vfnmsub.vf
 vfmacc.vf
 vfnmacc.vf
 vfmsac.vf
 vfnmsac.vf
 vfwadd.vf
 vfwsub.vf
 vfwadd.wf
 vfwsub.wf
 vfwmul.vf
 vfwmacc.vf
 vfwnmacc.vf
 vfwmsac.vf
 vfwnmsac.vf
 vfadd.vv
 vfredusum.vs
 vfsub.vv
 vfredosum.vs
 vfmin.vv
 vfredmin.vs
 vfmax.vv
 vfredmax.vs
 vfsgnj.vv
 vfsgnjn.vv
 vfsgnjx.vv
 vfmv.f.s
 vmfeq.vv
 vmfle.vv
 vmflt.vv
 vmfne.vv
 vfdiv.vv
 vfmul.vv
 vfmadd.vv
 vfnmadd.vv
 vfmsub.vv
 vfnmsub.vv
 vfmacc.vv
 vfnmacc.vv
 vfmsac.vv
 vfnmsac.vv
 vfcvt.xu.f.v
 vfcvt.x.f.v
 vfcvt.f.xu.v
 vfcvt.f.x.v
 vfcvt.rtz.xu.f.v
 vfcvt.rtz.x.f.v
 vfwcvt.xu.f.v
 vfwcvt.x.f.v
 vfwcvt.f.xu.v
 vfwcvt.f.x.v
 vfwcvt.f.f.v
 vfwcvt.rtz.xu.f.v
 vfwcvt.rtz.x.f.v
 vfncvt.xu.f.w
 vfncvt.x.f.w
 vfncvt.f.xu.w
 vfncvt.f.x.w
 vfncvt.f.f.w
 vfncvt.rod.f.f.w
 vfncvt.rtz.xu.f.w
 vfncvt.rtz.x.f.w
 vfsqrt.v
 vfrsqrt7.v
 vfrec7.v
 vfclass.v
 vfwadd.vv
 vfwredusum.vs
 vfwsub.vv
 vfwredosum.vs
 vfwadd.wv
 vfwsub.wv
 vfwmul.vv
 vfwmacc.vv
 vfwnmacc.vv
 vfwmsac.vv
 vfwnmsac.vv
 vadd.vx
 vsub.vx
 vrsub.vx
 vminu.vx
 vmin.vx
 vmaxu.vx
 vmax.vx
 vand.vx
 vor.vx
 vxor.vx
 vrgather.vx
 vslideup.vx
 vslidedown.vx
 vadc.vxm
 vmadc.vxm
 vmadc.vx
 vsbc.vxm
 vmsbc.vxm
 vmsbc.vx
 vmerge.vxm
 vmv.v.x
 vmseq.vx
 vmsne.vx
 vmsltu.vx
 vmslt.vx
 vmsleu.vx
 vmsle.vx
 vmsgtu.vx
 vmsgt.vx
 vsaddu.vx
 vsadd.vx
 vssubu.vx
 vssub.vx
 vsll.vx
 vsmul.vx
 vsrl.vx
 vsra.vx
 vssrl.vx
 vssra.vx
 vnsrl.wx
 vnsra.wx
 vnclipu.wx
 vnclip.wx
 vadd.vv
 vsub.vv
 vminu.vv
 vmin.vv
 vmaxu.vv
 vmax.vv
 vand.vv
 vor.vv
 vxor.vv
 vrgather.vv
 vrgatherei16.vv
 vadc.vvm
 vmadc.vvm
 vmadc.vv
 vsbc.vvm
 vmsbc.vvm
 vmsbc.vv
 vmerge.vvm
 vmv.v.v
 vmseq.vv
 vmsne.vv
 vmsltu.vv
 vmslt.vv
 vmsleu.vv
 vmsle.vv
 vsaddu.vv
 vsadd.vv
 vssubu.vv
 vssub.vv
 vsll.vv
 vsmul.vv
 vsrl.vv
 vsra.vv
 vssrl.vv
 vssra.vv
 vnsrl.wv
 vnsra.wv
 vnclipu.wv
 vnclip.wv
 vwredsumu.vs
 vwredsum.vs
 vadd.vi
 vrsub.vi
 vand.vi
 vor.vi
 vxor.vi
 vrgather.vi
 vslideup.vi
 vslidedown.vi
 vadc.vim
 vmadc.vim
 vmadc.vi
 vmerge.vim
 vmv.v.i
 vmseq.vi
 vmsne.vi
 vmsleu.vi
 vmsle.vi
 vmsgtu.vi
 vmsgt.vi
 vsaddu.vi
 vsadd.vi
 vsll.vi
 vmv1r.v
 vmv2r.v
 vmv4r.v
 vmv8r.v
 vsrl.vi
 vsra.vi
 vssrl.vi
 vssra.vi
 vnsrl.wi
 vnsra.wi
 vnclipu.wi
 vnclip.wi
 vredsum.vs
 vredand.vs
 vredor.vs
 vredxor.vs
 vredminu.vs
 vredmin.vs
 vredmaxu.vs
 vredmax.vs
 vaaddu.vv
 vaadd.vv
 vasubu.vv
 vasub.vv
 vmv.x.s
 vzext.vf8
 vsext.vf8
 vzext.vf4
 vsext.vf4
 vzext.vf2
 vsext.vf2
 vcompress.vm
 vmandn.mm
 vmand.mm
 vmor.mm
 vmxor.mm
 vmorn.mm
 vmnand.mm
 vmnor.mm
 vmxnor.mm
 vmsbf.m
 vmsof.m
 vmsif.m
 viota.m
 vid.v
 vcpop.m
 vfirst.m
 vdivu.vv
 vdiv.vv
 vremu.vv
 vrem.vv
 vmulhu.vv
 vmul.vv
 vmulhsu.vv
 vmulh.vv
 vmadd.vv
 vnmsub.vv
 vmacc.vv
 vnmsac.vv
 vwaddu.vv
 vwadd.vv
 vwsubu.vv
 vwsub.vv
 vwaddu.wv
 vwadd.wv
 vwsubu.wv
 vwsub.wv
 vwmulu.vv
 vwmulsu.vv
 vwmul.vv
 vwmaccu.vv
 vwmacc.vv
 vwmaccsu.vv
 vaaddu.vx
 vaadd.vx
 vasubu.vx
 vasub.vx
 vmv.s.x
 vslide1up.vx
 vslide1down.vx
 vdivu.vx
 vdiv.vx
 vremu.vx
 vrem.vx
 vmulhu.vx
 vmul.vx
 vmulhsu.vx
 vmulh.vx
 vmadd.vx
 vnmsub.vx
 vmacc.vx
 vnmsac.vx
 vwaddu.vx
 vwadd.vx
 vwsubu.vx
 vwsub.vx
 vwaddu.wx
 vwadd.wx
 vwsubu.wx
 vwsub.wx
 vwmulu.vx
 vwmulsu.vx
 vwmul.vx
 vwmaccu.vx
 vwmacc.vx
 vwmaccus.vx
 vwmaccsu.vx)
