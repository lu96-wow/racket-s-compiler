#lang racket/base

;; ============================================================
;; li：展开结果与语义
;; ============================================================

(require rackunit
         racket/list
         racket/match
         "../li.rkt"
         "../ranges.rkt"
         "../registers.rkt")

(define (eval-li-sequence sequence word-size)
  (define xlen
    (case word-size
      [(rv32) 32]
      [(rv64) 64]
      [else (error 'eval-li-sequence "unknown word size: ~a" word-size)]))
  (define mask (sub1 (arithmetic-shift 1 xlen)))
  (define regs (make-hash))
  (define (read-reg reg)
    (if (zero-register? reg)
        0
        (hash-ref regs reg 0)))
  (define (write-reg reg value)
    (unless (zero-register? reg)
      (hash-set! regs reg (bitwise-and value mask))))
  (for ([insn (in-list sequence)])
    (match insn
      [(list 'addi rd rs1 imm)
       (write-reg rd (+ (read-reg rs1) imm))]
      [(list 'addiw rd rs1 imm)
       (write-reg rd
                  (sign-extend 32
                               (bitwise-and (+ (read-reg rs1) imm)
                                            #xFFFFFFFF)))]
      [(list 'lui rd imm20)
       (define value (arithmetic-shift imm20 12))
       (write-reg rd
                  (if (eq? word-size 'rv64)
                      (sign-extend 32 value)
                      value))]
      [(list 'slli rd rs1 shamt)
       (write-reg rd (arithmetic-shift (read-reg rs1) shamt))]
      [(list 'srli rd rs1 shamt)
       (write-reg rd (arithmetic-shift (read-reg rs1) (- shamt)))]
      [(list 'or rd rs1 rs2)
       (write-reg rd (bitwise-ior (read-reg rs1) (read-reg rs2)))]
      [_
       (error 'eval-li-sequence "unsupported instruction: ~a" insn)]))
  (read-reg 'a0))

(define rv64-values
  (list 0
        1
        -1
        2047
        2048
        -2048
        -2049
        #x7fffffff
        #x80000000
        #xffffffff
        #x7ffff800
        #x123456789abcdef
        #xdeadbeefcafebabe
        #x8000000000000000
        #xffffffffffffffff
        #x0000000100000000
        #x00000000ffffffff
        #x1234567800000000
        #x0000000012345678))

(for ([value (in-list rv64-values)])
  (check-equal?
   (eval-li-sequence (expand-li 'a0 value #:word-size 'rv64) 'rv64)
   (bitwise-and value #xFFFFFFFFFFFFFFFF)
   (format "rv64 li ~x" value)))

;; 随机 64 位值做一遍语义回归。
(define (random-u32)
  (bitwise-ior (random 65536)
               (arithmetic-shift (random 65536) 16)))

(random-seed 20241024)
(for ([_ (in-range 1000)])
  (define value
    (bitwise-ior (random-u32)
                 (arithmetic-shift (random-u32) 32)))
  (check-equal?
   (eval-li-sequence (expand-li 'a0 value #:word-size 'rv64) 'rv64)
   value
   (format "rv64 random li ~x" value)))

(define rv32-values
  (list 0
        1
        -1
        2047
        2048
        -2048
        -2049
        #x7fffffff
        #x80000000
        #xffffffff
        #x12345678))

(for ([value (in-list rv32-values)])
  (check-equal?
   (eval-li-sequence (expand-li 'a0 value #:word-size 'rv32) 'rv32)
   (bitwise-and value #xFFFFFFFF)
   (format "rv32 li ~x" value)))

;; signed-32 但 LUI+ADDI 会算错的典型值：必须用 ADDIW。
(check-equal? (expand-li 'a0 #x7fffffff #:word-size 'rv64)
              '((lui a0 524288) (addiw a0 a0 -1)))
(check-equal? (expand-li 'a0 #x7ffff800 #:word-size 'rv64)
              '((lui a0 524288) (addiw a0 a0 -2048)))

;; 正的 32 位值需要零扩展。
(check-equal? (expand-li 'a0 #x80000000 #:word-size 'rv64)
              '((lui a0 524288) (slli a0 a0 32) (srli a0 a0 32)))
(check-equal? (expand-li 'a0 #xffffffff #:word-size 'rv64)
              '((addi a0 x0 -1) (slli a0 a0 32) (srli a0 a0 32)))

;; 一般 64 位值走 GAS 风格的 shift 递归。
(check-equal? (expand-li 'a0 #x123456789abcdef #:word-size 'rv64)
              '((lui a0 596523)
                (addi a0 a0 965)
                (slli a0 a0 32)
                (srli a0 a0 32)
                (slli a0 a0 13)
                (addi a0 a0 -1347)
                (slli a0 a0 12)
                (addi a0 a0 -529)))

(check-exn exn:fail?
           (lambda () (expand-li 'a0 #x100000000 #:word-size 'rv32)))
(check-exn exn:fail?
           (lambda () (expand-li 'a0 #x10000000000000000 #:word-size 'rv64)))
(check-exn exn:fail?
           (lambda () (li-lui-addiw 'a0 5 #:word-size 'rv32)))

;; ------------------------------------------------------------
;; 自动入口 li / li-size
;; ------------------------------------------------------------

(for ([value (in-list (list 5
                           #x800
                           #x7fffffff
                           #x123456789abcdef))])
  (check-equal? (li 'a0 value #:word-size 'rv64)
                (expand-li 'a0 value #:word-size 'rv64)))

(check-equal? (li-size 5 #:word-size 'rv32) 4)
(check-equal? (li-size 5 #:word-size 'rv64) 4)
(check-equal? (li-size 4096 #:word-size 'rv64) 4)
(check-equal? (li-size 2048 #:word-size 'rv64) 8)
(check-equal? (li-size #x7fffffff #:word-size 'rv64) 8)
(check-equal? (li-size #x80000000 #:word-size 'rv64) 12)
(check-equal? (li-size #x123456789abcdef #:word-size 'rv64) 32)

(check-exn exn:fail?
           (lambda () (li 'a0 #x100000000 #:word-size 'rv32)))
(check-exn exn:fail?
           (lambda () (li-size #x100000000 #:word-size 'rv32)))
