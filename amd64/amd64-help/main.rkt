#lang racket
;;; amd64-help/main.rkt
;;;
;;; Stable public API of the amd64 expansion-helper layer.  Leaf helpers stay
;;; private; compiler/expand-pseudo consumes this module rather than copying
;;; condition-code or branch policy.

(require "ranges.rkt"
         "li.rkt"
         "cc.rkt"
         "branch.rkt")

(provide
 ;; constant / RIP-relative address expansion
 li->form
 li-size

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
