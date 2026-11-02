#lang racket
;;; amd64-help/branch.rkt
;;;
;;; Control-transfer form selection.  Forms are explicit: short vs near is a
;;; strategy choice made here, never a last-minute encoder decision.

(provide jump-form
         branch-form
         branch-inverse
         control-transfer-mnemonics
         control-transfer-form?
         control-transfer-name?
         short-control-transfer-form?
         near-control-transfer-form?
         control-transfer-target
         control-transfer-fits?)

(require "../amd64-asm/shape.rkt"
         "../amd64-asm/ranges.rkt")

(define control-transfer-mnemonics
  '(jmp-short jmp-near jcc-short jcc-near call-near))

(define (control-transfer-form? x)
  (and (form? x) (memq (car x) control-transfer-mnemonics) #t))

(define (control-transfer-name? name)
  (and (memq name control-transfer-mnemonics) #t))

(define (short-control-transfer-form? x)
  (and (control-transfer-form? x)
       (memq (car x) '(jmp-short jcc-short))
       #t))

(define (near-control-transfer-form? x)
  (and (control-transfer-form? x)
       (memq (car x) '(jmp-near jcc-near call-near))
       #t))

(define (control-transfer-target x) (last x))

;; 这个形式能不能用位移 DISP 编出来。范围常量在 amd64-asm/ranges.rkt:
;; 这里只决定"哪一类形式用哪个范围", 不重复写数字。
(define (control-transfer-fits? x disp)
  (cond
    [(short-control-transfer-form? x) (fits-rel8? disp)]
    [(near-control-transfer-form? x) (fits-rel32? disp)]
    [else #f]))

(define (jump-form target short?)
  (if short? (list 'jmp-short target) (list 'jmp-near target)))

(define (branch-form cc target short?)
  (if short? (list 'jcc-short cc target) (list 'jcc-near cc target)))

;; For a future long-branch/trampoline expansion.  This is intentionally a
;; pure name inversion; scratch/far sequences belong to a later helper.
(define (branch-inverse cc)
  (case cc
    [(e) 'ne] [(ne) 'e]
    [(b) 'ae] [(ae) 'b]
    [(be) 'a] [(a) 'be]
    [(s) 'ns] [(ns) 's]
    [(p) 'np] [(np) 'p]
    [(l) 'ge] [(ge) 'l]
    [(le) 'g] [(g) 'le]
    [(o) 'no] [(no) 'o]
    [else (error 'branch-inverse "unknown condition code: ~e" cc)]))
