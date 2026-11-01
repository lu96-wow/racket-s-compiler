#lang racket
;;; amd64-help/main.rkt
;;;
;;; Stable public API of the amd64 expansion-helper layer.  Leaf helpers stay
;;; private; compiler/expand-pseudo consumes this module rather than copying
;;; condition-code or branch policy.

(require "ranges.rkt"
         "li.rkt"
         "la.rkt"
         "cc.rkt"
         "branch.rkt"
         "jump.rkt"
         "scratch.rkt")

(provide
 ;; constant / RIP-relative address expansion
 li->form
 li-size
 la-pcrel
 la-frame
 la-abs
 la-size

 ;; call / indirect / far placeholders
 call-form
 call-indirect-form
 jump-indirect-form
 jump-far-form
 call-far-form

 ;; scratch rules
 default-scratch
 scratch-list
 check-distinct!
 check-scratch-register!
 take-scratch!

 ;; condition codes / branch forms
 canonical-cc
 jcc-alias?
 jump-form
 branch-form
 branch-inverse

 ;; ranges
 fits-s8?
 fits-s16?
 fits-s32?
 fits-u8?
 fits-u32?
 fits-rel8?
 fits-rel32?
 fits-disp32?
 fits-width?)
