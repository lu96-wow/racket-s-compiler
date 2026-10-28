#lang racket/base

;; ============================================================
;; F-asm：值表示与基本形式
;;
;; 一个机器字一个 tagged value：
;;   000 fixnum
;;   001 char
;;   010 cons
;;   011 symbol
;;   100 string
;;   101 vector / box
;;   110 procedure（closure / continuation）
;;   111 special： #f=7 #t=15 nil=23 eof=31
;;
;; F-asm 是“Scheme 运行时的汇编”，不是 C 的三地址 IR。
;; ============================================================

(require racket/list)

(provide fasm?
         fasm-items
         fasm-label?
         fasm-label-name

         VALUE-TAG-MASK
         TAG-FIXNUM TAG-CHAR TAG-CONS TAG-SYMBOL TAG-STRING TAG-VECTOR TAG-PROCEDURE TAG-SPECIAL

         FALSE TRUE NIL EOF
         immediate?
         pointer?
         tag-of
         pointer-index
         make-pointer

         fixnum? encode-fixnum decode-fixnum
         char-value? encode-char decode-char
         boolean-value?
         nil-value?
         special-value?)

;; ------------------------------------------------------------
;; 程序形态
;; ------------------------------------------------------------

(define (fasm? value)
  (and (list? value)
       (pair? value)
       (eq? (car value) 'fasm)))

(define (fasm-items program)
  (unless (fasm? program)
    (error 'fasm-items "expected (fasm ...), got: ~a" program))
  (cdr program))

(define (fasm-label? value)
  (and (list? value)
       (= (length value) 2)
       (eq? (car value) 'label)
       (symbol? (cadr value))))

(define (fasm-label-name value)
  (cadr value))

;; ------------------------------------------------------------
;; tag
;; ------------------------------------------------------------

(define VALUE-TAG-MASK 7)

(define TAG-FIXNUM 0)
(define TAG-CHAR 1)
(define TAG-CONS 2)
(define TAG-SYMBOL 3)
(define TAG-STRING 4)
(define TAG-VECTOR 5)
(define TAG-PROCEDURE 6)
(define TAG-SPECIAL 7)

(define FALSE (bitwise-ior (arithmetic-shift 0 3) TAG-SPECIAL))   ; 7
(define TRUE  (bitwise-ior (arithmetic-shift 1 3) TAG-SPECIAL))   ; 15
(define NIL   (bitwise-ior (arithmetic-shift 2 3) TAG-SPECIAL))   ; 23
(define EOF   (bitwise-ior (arithmetic-shift 3 3) TAG-SPECIAL))   ; 31

(define (tag-of value)
  (bitwise-and value VALUE-TAG-MASK))

(define (pointer-index value)
  (arithmetic-shift value -3))

(define (make-pointer index tag)
  (unless (exact-nonnegative-integer? index)
    (error 'make-pointer "bad heap index: ~a" index))
  (unless (memq tag (list TAG-CONS TAG-SYMBOL TAG-STRING TAG-VECTOR TAG-PROCEDURE))
    (error 'make-pointer "bad pointer tag: ~a" tag))
  (bitwise-ior (arithmetic-shift index 3) tag))

(define (immediate? value)
  (memq (tag-of value) (list TAG-FIXNUM TAG-CHAR TAG-SPECIAL)))

(define (pointer? value)
  (memq (tag-of value) (list TAG-CONS TAG-SYMBOL TAG-STRING TAG-VECTOR TAG-PROCEDURE)))

;; ------------------------------------------------------------
;; fixnum
;; ------------------------------------------------------------

(define (fixnum? value)
  (eq? (tag-of value) TAG-FIXNUM))

(define (encode-fixnum n)
  (unless (exact-integer? n)
    (error 'encode-fixnum "not an integer: ~a" n))
  (arithmetic-shift n 3))

(define (decode-fixnum value)
  (unless (fixnum? value)
    (error 'decode-fixnum "not a fixnum: ~a" value))
  (arithmetic-shift value -3))

;; ------------------------------------------------------------
;; char
;; ------------------------------------------------------------

(define (char-value? value)
  (eq? (tag-of value) TAG-CHAR))

(define (encode-char ch)
  (bitwise-ior (arithmetic-shift (char->integer ch) 3) TAG-CHAR))

(define (decode-char value)
  (unless (char-value? value)
    (error 'decode-char "not a char: ~a" value))
  (integer->char (arithmetic-shift value -3)))

;; ------------------------------------------------------------
;; special
;; ------------------------------------------------------------

(define (special-value? value)
  (eq? (tag-of value) TAG-SPECIAL))

(define (boolean-value? value)
  (or (= value FALSE) (= value TRUE)))

(define (nil-value? value)
  (= value NIL))
