#lang racket
;;; amd64/amd64-asm/ranges.rkt
;;;
;;; Pure integer range facts shared by instruction planning, special plans
;;; and amd64-help.  No layer policy lives here.

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

(define (fits-s8? n) (<= -128 n 127))
(define (fits-s16? n) (<= (- (expt 2 15)) n (sub1 (expt 2 15))))
(define (fits-s32? n) (<= (- (expt 2 31)) n (sub1 (expt 2 31))))
(define (fits-u8? n) (<= 0 n 255))
(define (fits-u32? n) (<= 0 n (sub1 (expt 2 32))))

;; Byte/word/dword/qword immediates may be written as either sign-extended
;; negative values or full unsigned patterns.
(define (fits-any8? n) (<= -128 n 255))
(define (fits-any16? n) (<= (- (expt 2 15)) n (sub1 (expt 2 16))))
(define (fits-any32? n) (<= (- (expt 2 31)) n (sub1 (expt 2 32))))
(define (fits-any64? n) (<= (- (expt 2 63)) n (sub1 (expt 2 64))))

;; x86 branch offsets are signed.
(define fits-rel8? fits-s8?)
(define fits-rel32? fits-s32?)

;; ModR/M disp32 is stored as a 32-bit two's-complement pattern.
(define fits-disp32? fits-any32?)

;; Signed-or-unsigned value fits in WIDTH bytes (data value check).
(define (fits-width? n width)
  (define bits (* 8 width))
  (<= (- (expt 2 (sub1 bits))) n (sub1 (expt 2 bits))))
