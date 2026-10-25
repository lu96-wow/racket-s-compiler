#lang racket/base

;; ============================================================
;; 汇编 S-expr 的基础判断
;;
;; (label name)
;; (mnemonic operand ...)
;; ============================================================

(require racket/string
         "frame.rkt")

(provide label?
         instruction?
         vreg?
         vreg-index
         physical-register?
         instruction-size
         branch-mnemonics
         branch-instruction?
         jal-instruction?
         jalr-instruction?
         terminator?
         unconditional-jump?
         return-instruction?)

(define (label? value)
  (and (list? value)
       (= (length value) 2)
       (eq? (car value) 'label)
       (symbol? (cadr value))))

(define (instruction? value)
  (and (list? value)
       (pair? value)
       (symbol? (car value))
       (not (eq? (car value) 'label))
       (not (declaration-form? value))))

;; ------------------------------------------------------------
;; 物理寄存器
;; ------------------------------------------------------------

(define physical-registers
  '(x0 ra sp gp tp
    t0 t1 t2 t3 t4 t5 t6
    s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11
    a0 a1 a2 a3 a4 a5 a6 a7))

(define (physical-register? value)
  (and (symbol? value)
       (memq value physical-registers)
       #t))

(define (vreg-index value)
  (and (symbol? value)
       (let ([s (symbol->string value)])
         (and (> (string-length s) 1)
              (char=? (string-ref s 0) #\v)
              (let ([n (string->number (substring s 1))])
                (and n (exact-nonnegative-integer? n) n))))))

(define (vreg? value)
  (and (vreg-index value) #t))

(define (instruction-size instruction)
  (define mnemonic (car instruction))
  (if (string-prefix? (symbol->string mnemonic) "c.")
      2
      4))


;; ------------------------------------------------------------
;; 控制流相关判断
;; ------------------------------------------------------------

(define branch-mnemonics
  '(beq bne blt bge bltu bgeu))

(define (branch-instruction? instruction)
  (and (instruction? instruction)
       (memq (car instruction) branch-mnemonics)))

(define (jal-instruction? instruction)
  (and (instruction? instruction)
       (eq? (car instruction) 'jal)))

(define (jalr-instruction? instruction)
  (and (instruction? instruction)
       (eq? (car instruction) 'jalr)))

(define (terminator? instruction)
  (or (branch-instruction? instruction)
      (jal-instruction? instruction)
      (jalr-instruction? instruction)
      (tailcall-form? instruction)
      (return-form? instruction)))

;; (jal x0 label)
(define (unconditional-jump? instruction)
  (and (jal-instruction? instruction)
       (eq? (cadr instruction) 'x0)))

;; (jalr x0 ra 0)
(define (return-instruction? instruction)
  (and (jalr-instruction? instruction)
       (eq? (cadr instruction) 'x0)
       (eq? (caddr instruction) 'ra)))
