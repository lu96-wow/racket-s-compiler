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
;;
;; 每个函数只接受一个明确形式，不自动回退。
;; 长分支的 jump sequence 由调用者通过 jump-expander 显式提供。
;; ============================================================

(require racket/string
         "ranges.rkt"
         "registers.rkt"
         "jump.rkt")

;; 指令统一用 list 表示：
;;   (mnemonic arg ...)
;; 大小由 mnemonic 决定：c.* 为 2 字节，其余为 4 字节。
(define (instruction? value)
  (and (list? value)
       (pair? value)
       (symbol? (car value))))

(define (instruction-size instruction)
  (define mnemonic (car instruction))
  (if (string-prefix? (symbol->string mnemonic) "c.")
      2
      4))

(define (instructions-size instructions)
  (for/sum ([instruction (in-list instructions)])
    (instruction-size instruction)))

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
  (unless (compressed-branch-register? rs1)
    (error 'branch-c
           "compressed branch requires rs1 in x8..x15, got ~a"
           rs1))
  (unless (fits-cbranch? offset)
    (error 'branch-c "offset ~a does not fit compressed branch" offset))
  (list (list mnemonic rs1 offset)))

(define (branch-b mnemonic rs1 rs2 offset)
  (unless (memq mnemonic '(beq bne blt bge bltu bgeu))
    (error 'branch-b "not a B-type branch: ~a" mnemonic))
  (unless (fits-branch? offset)
    (error 'branch-b "offset ~a does not fit B-type branch" offset))
  (list (list mnemonic rs1 rs2 offset)))

(define (branch-long mnemonic rs1 rs2 offset jump-expander)
  (unless (even? offset)
    (error 'branch-long "offset must be even, got ~a" offset))
  (unless (procedure? jump-expander)
    (error 'branch-long "jump-expander must be a procedure"))
  (define inverse (branch-inverse mnemonic))
  (define jump
    (jump-expander (- offset 4)))
  (unless (and (list? jump)
               (pair? jump)
               (andmap instruction? jump))
    (error 'branch-long
           "jump-expander must return a non-empty list of instructions"))
  (define skip (+ 4 (instructions-size jump)))
  (unless (fits-branch? skip)
    (error 'branch-long
           "inverse-branch skip ~a does not fit B-type range"
           skip))
  (cons (list inverse rs1 rs2 skip)
        jump))

(provide branch-inverse
         branch-c
         branch-b
         branch-long)
