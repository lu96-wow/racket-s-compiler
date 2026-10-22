#lang racket/base

(require rackunit
         (prefix-in raw: "../raw/vector.rkt")
         (prefix-in rebuilt: "../rebuilt/vector.rkt"))

(check-equal? (raw:vd 31) #xF80)
(check-equal? (raw:vs1 31) #xF8000)
(check-equal? (raw:vs2 31) #x1F00000)
(check-equal? (raw:vs3 31) #xF80)
(check-equal? (raw:vm 1) #x2000000)
(check-equal? (raw:nf 7) #xE0000000)
(check-equal? (raw:wd 1) #x4000000)

(check-equal? (raw:simm5 -1) #xF8000)
(check-equal? (raw:zimm10 1023) #x3FF00000)
(check-equal? (raw:zimm11 2047) #x7FF00000)

(check-equal? (raw:zimm6lo 31) #xF8000)
(check-equal? (raw:zimm6hi 32) #x4000000)
(check-equal? (rebuilt:zimm6 63) #x40F8000)

(check-equal? (raw:vs2x8 3) #x1800000)
(check-equal? (raw:ci 7) #x700000)
(check-equal? (raw:amoop 31) #xF8000000)

(displayln "vector field tests passed")
