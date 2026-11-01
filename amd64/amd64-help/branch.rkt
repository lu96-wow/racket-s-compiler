#lang racket
;;; amd64-help/branch.rkt
;;;
;;; Control-transfer form selection.  Forms are explicit: short vs near is a
;;; strategy choice made here, never a last-minute encoder decision.

(provide jump-form
         branch-form
         branch-inverse)

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
