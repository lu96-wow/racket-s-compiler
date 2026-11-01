#lang racket
;;; amd64-help/ranges.rkt
;;;
;;; Help-layer view of the shared integer range facts.  The canonical
;;; predicates live in amd64-asm/ranges.rkt so plan/encode and expansion
;;; policy cannot disagree about signed/unsigned/immediate limits.

(require "../amd64-asm/ranges.rkt")

(provide fits-s8?
         fits-s16?
         fits-s32?
         fits-u8?
         fits-u32?
         fits-any8?
         fits-any16?
         fits-any32?
         fits-any64?
         fits-rel8?
         fits-rel32?
         fits-disp32?
         fits-width?)
