#lang racket/base

(require rackunit
         (prefix-in raw: "../raw/mop.rkt")
         (prefix-in rebuilt: "../rebuilt/mop.rkt"))

(check-equal? (raw:mop_r_t_30 #b10000) #x40000000)
(check-equal? (raw:mop_r_t_27_26 #b1100) #xC000000)
(check-equal? (raw:mop_r_t_21_20 #b11) #x300000)
(check-equal? (rebuilt:mop_r_t 0) 0)
(check-equal? (rebuilt:mop_r_t 1) #x100000)
(check-equal? (rebuilt:mop_r_t 31) #x4C300000)

(check-equal? (raw:mop_rr_t_30 #b10000) #x40000000)
(check-equal? (raw:mop_rr_t_27_26 #b1100) #xC000000)
(check-equal? (rebuilt:mop_rr_t 7) #x4000000)
(check-equal? (rebuilt:mop_rr_t 12) #xC000000)
(check-equal? (rebuilt:mop_rr_t 31) #x4C000000)

(displayln "mop field tests passed")
