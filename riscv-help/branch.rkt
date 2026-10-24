#lang racket/base

;; ============================================================
;; 条件分支
;;
;; 短分支：
;;   c.beqz / c.bnez
;;   beq / bne / blt / bge / bltu / bgeu
;;
;; 长分支：
;;   inverse-branch skip
;;   <jump sequence>
;;
;; skip = 4 + jump-size
;; ============================================================

(require "instruction.rkt"
         "ranges.rkt"
         "registers.rkt"
         "jump.rkt")

(define (branch-inverse mnemonic)
  (case mnemonic
    [(beq)  'bne]
    [(bne)  'beq]
    [(blt)  'bge]
    [(bge)  'blt]
    [(bltu) 'bgeu]
    [(bgeu) 'bltu]
    [else
     (error 'branch-inverse "not a canonical branch: ~a" mnemonic)]))

;; ------------------------------------------------------------
;; 叶子函数
;; ------------------------------------------------------------

(define (branch-c mnemonic rs1 offset)
  (unless (memq mnemonic '(c.beqz c.bnez))
    (error 'branch-c "expected c.beqz or c.bnez, got ~a" mnemonic))
  (unless (compressed-register? rs1)
    (error 'branch-c
           "compressed branch requires rs1 in x8..x15, got ~a"
           rs1))
  (unless (fits-cbranch? offset)
    (error 'branch-c "offset ~a does not fit compressed branch" offset))
  (list (I16 mnemonic rs1 offset)))

(define (branch-b mnemonic rs1 rs2 offset)
  (unless (memq mnemonic '(beq bne blt bge bltu bgeu))
    (error 'branch-b "not a B-type branch: ~a" mnemonic))
  (unless (fits-branch? offset)
    (error 'branch-b "offset ~a does not fit B-type branch" offset))
  (list (I mnemonic rs1 rs2 offset)))

(define (branch-long mnemonic rs1 rs2 offset
                     #:scratch [scratch #f]
                     #:word-size [word-size 'rv64]
                     #:compressed-jump? [compressed-jump? #f])
  (define inverse (branch-inverse mnemonic))
  (define jump
    (expand-jump (- offset 4)
                 #:link 'zero
                 #:scratch scratch
                 #:word-size word-size
                 #:compressed? compressed-jump?))
  (define skip (+ 4 (insns-size jump)))
  (cons (I inverse rs1 rs2 skip)
        jump))

;; ------------------------------------------------------------
;; 组合
;; ------------------------------------------------------------

(define (expand-branch mnemonic rs1 rs2 offset
                       #:scratch [scratch #f]
                       #:word-size [word-size 'rv64]
                       #:compressed? [compressed? #f])
  (unless (even? offset)
    (error 'expand-branch "offset must be even, got ~a" offset))

  (cond
    ;; beq rs1, x0 等价于 c.beqz
    [(and compressed?
          (eq? mnemonic 'beq)
          (zero-register? rs2)
          (compressed-register? rs1)
          (fits-cbranch? offset))
     (branch-c 'c.beqz rs1 offset)]

    ;; bne rs1, x0 等价于 c.bnez
    [(and compressed?
          (eq? mnemonic 'bne)
          (zero-register? rs2)
          (compressed-register? rs1)
          (fits-cbranch? offset))
     (branch-c 'c.bnez rs1 offset)]

    [(fits-branch? offset)
     (branch-b mnemonic rs1 rs2 offset)]

    [else
     (branch-long mnemonic rs1 rs2 offset
                  #:scratch scratch
                  #:word-size word-size
                  #:compressed-jump? compressed?)]))

(provide branch-inverse
         branch-c
         branch-b
         branch-long
         expand-branch)
