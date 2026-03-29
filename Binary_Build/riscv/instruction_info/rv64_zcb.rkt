#lang racket

(define rv64_zcb-rd_rs1_p
  (make-immutable-hash
    '(
      (c.zext.w . 1)
    )))

(define rv64_zcb-fields '(rd_rs1_p ))

(provide
  rv64_zcb-rd_rs1_p
  rv64_zcb-fields)
