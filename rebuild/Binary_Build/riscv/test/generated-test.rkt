#lang racket/base

(require rackunit
         racket/file
         racket/path
         racket/runtime-path
         racket/string
         (prefix-in raw-c: "../instruction/raw/rv_c.rkt")
         (prefix-in rebuilt-c: "../instruction/rebuilt/rv_c.rkt")
         (prefix-in raw-v: "../instruction/raw/rv_v.rkt")
         (prefix-in rebuilt-v: "../instruction/rebuilt/rv_v.rkt")
         (prefix-in raw-zvbb: "../instruction/raw/rv_zvbb.rkt")
         (prefix-in rebuilt-zvbb: "../instruction/rebuilt/rv_zvbb.rkt")
         (prefix-in raw-mop: "../instruction/raw/rv_zimop.rkt")
         (prefix-in rebuilt-mop: "../instruction/rebuilt/rv_zimop.rkt")
         (prefix-in raw-d: "../instruction/raw/rv_d.rkt")
         (prefix-in rebuilt-d: "../instruction/rebuilt/rv_d.rkt")
         (prefix-in raw-i: "../instruction/raw/rv_i.rkt")
         (prefix-in rebuilt-i: "../instruction/rebuilt/rv_i.rkt")
         (prefix-in raw-zbc: "../instruction/raw/rv_zbc.rkt")
         (prefix-in raw-zbkc: "../instruction/raw/rv_zbkc.rkt"))

;; 所有生成模块都必须能加载
(define (load-all dir)
  (for ([name (in-list (directory-list dir))])
    (define p (build-path dir name))
    (when (and (file-exists? p)
               (not (directory-exists? p)))
      (dynamic-require p #f))))

(define-runtime-path raw-dir "../instruction/raw")
(define-runtime-path rebuilt-dir "../instruction/rebuilt")

(load-all raw-dir)
(load-all rebuilt-dir)

;; ------------------------------------------------------------
;; raw / rebuilt 编码一致性
;; ------------------------------------------------------------

;; c.lw x8, 4(x9)
(check-equal? (raw-c:c.lw 8 9 4 4)
              (rebuilt-c:c.lw 8 9 4))
(check-equal? (rebuilt-c:c.lw 8 9 4) #x40C0)

;; c.addi x1, -1
(check-equal? (raw-c:c.addi 1 -1 -1)
              (rebuilt-c:c.addi 1 -1))

;; vle32.v v0, (x1), v0
(check-equal? (raw-v:vle32.v 0 1 1 0)
              (rebuilt-v:vle32.v 0 1 1 0))

;; vror.vi v4, v2, 3, v0
(check-equal? (raw-zvbb:vror.vi 3 0 2 3 4)
              (rebuilt-zvbb:vror.vi 3 0 2 4))

;; mop.r.5 x2, x1
(check-equal? (raw-mop:mop.r.N 5 5 5 2 1)
              (rebuilt-mop:mop.r.N 5 2 1))


;; ------------------------------------------------------------
;; alias / pseudo / import
;; ------------------------------------------------------------

;; fmv.d rd, rs1 == fsgnj.d rd, rs1, rs1
(check-equal? (raw-d:fmv.d 1 2)
              (raw-d:fsgnj.d 1 2 2))
(check-equal? (rebuilt-d:fmv.d 1 2)
              (rebuilt-d:fsgnj.d 1 2 2))

;; pseudo
(check-equal? (raw-i:nop) #x00000013)
(check-equal? (rebuilt-i:mv 1 2) #x00010093)

;; import
(check-equal? (raw-zbc:clmul 1 2 3)
              (raw-zbkc:clmul 1 2 3))
(check-equal? (raw-zbc:clmulh 1 2 3)
              (raw-zbkc:clmulh 1 2 3))

(displayln "generated instruction tests passed")
