#lang racket
;;; amd64/amd64-asm/memory.rkt
;;;
;;; amd64 memory operand shape and parser.
;;;
;;;   (b64 (base rax) (index rcx) (scale 4) (disp (+ (data) 8)) (seg fs))
;;;
;;; Defaults:
;;;   base/index/seg absent, disp = 0, scale = 1 when index exists.

(require "shape.rkt")

(provide mem-form?
         parse-mem
         (struct-out mem))

;; ---------------------------------------------------------------------------
;; 内存操作数
;;
;;   (b64 (base rax) (index rcx) (scale 4) (disp (+ (data) 8)) (seg fs))
;;
;; 缺省:
;;   base/index/seg 无
;;   disp 0
;;   index 存在时 scale 1
;; ---------------------------------------------------------------------------

(struct mem (width base index scale disp seg disp-width) #:transparent)

(define mem-heads '(b8 b16 b32 b64 b128))
(define mem-field-keys '(base index scale disp seg))

(define (mem-head-width head)
  (case head
    [(b8) 8]
    [(b16) 16]
    [(b32) 32]
    [(b64) 64]
    [(b128) 128]
    [else #f]))

(define (mem-field? x)
  (and (form? x)
       (= 2 (length x))
       (memq (car x) mem-field-keys)))

(define (mem-form? x)
  (and (form? x)
       (memq (car x) mem-heads)
       (andmap mem-field? (cdr x))))

(define (parse-mem x)
  (unless (mem-form? x)
    (error 'parse-mem "expected b8/b16/b32/b64 memory operand: ~e" x))
  (define width (mem-head-width (car x)))
  (define fields (cdr x))
  (define names (map car fields))
  (unless (= (length names) (length (remove-duplicates names eq?)))
    (error 'parse-mem "duplicate memory field: ~e" x))
  (define (field key default)
    (cond ((assq key fields) => cadr)
          [else default]))
  (define base (field 'base #f))
  (define index (field 'index #f))
  (define scale (field 'scale 1))
  (define disp (field 'disp 0))
  (define seg (field 'seg #f))
  (unless (or (not base) (symbol? base))
    (error 'parse-mem "bad base register: ~e" base))
  (unless (or (not index) (symbol? index))
    (error 'parse-mem "bad index register: ~e" index))
  (unless (memq scale '(1 2 4 8))
    (error 'parse-mem "bad scale: ~e" scale))
  (unless (or (not seg) (memq seg '(fs gs)))
    (error 'parse-mem "bad segment override: ~e" seg))
  (unless (address-expr? disp)
    (error 'parse-mem "bad displacement expression: ~e" disp))
  (when (and (not index) (not (= scale 1)))
    (error 'parse-mem "scale requires an index register: ~e" x))
  (mem width base index scale disp seg
       (if (exact-integer? disp) 'auto 32)))
