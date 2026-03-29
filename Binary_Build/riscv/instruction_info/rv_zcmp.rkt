#lang racket

(define rv_zcmp-c_rlist
  (make-immutable-hash
    '(
      (cm.push . 1)
      (cm.pop . 1)
      (cm.popretz . 1)
      (cm.popret . 1)
    )))
(define rv_zcmp-c_spimm
  (make-immutable-hash
    '(
      (cm.push . 2)
      (cm.pop . 2)
      (cm.popretz . 2)
      (cm.popret . 2)
    )))
(define rv_zcmp-c_sreg1
  (make-immutable-hash
    '(
      (cm.mvsa01 . 1)
      (cm.mva01s . 1)
    )))
(define rv_zcmp-c_sreg2
  (make-immutable-hash
    '(
      (cm.mvsa01 . 2)
      (cm.mva01s . 2)
    )))

(define rv_zcmp-fields '(c_rlist c_spimm c_sreg1 c_sreg2 ))

(provide
  rv_zcmp-c_rlist
  rv_zcmp-c_spimm
  rv_zcmp-c_sreg1
  rv_zcmp-c_sreg2
  rv_zcmp-fields)
