#lang racket/base

(require racket/string
         "struct.rkt")

;; ============================================================
;; 数字与固定位段解析
;;
;; riscv-opcodes 支持的数字形式：
;;   decimal, 0x/0b/0o, #x/#b/#o
;; ============================================================

(define (string->integer s line-number)
  (define (try str base)
    (string->number str base))
  (define value
    (cond
      [(string-prefix? s "0x") (try (substring s 2) 16)]
      [(string-prefix? s "0X") (try (substring s 2) 16)]
      [(string-prefix? s "0b") (try (substring s 2) 2)]
      [(string-prefix? s "0B") (try (substring s 2) 2)]
      [(string-prefix? s "0o") (try (substring s 2) 8)]
      [(string-prefix? s "0O") (try (substring s 2) 8)]
      [(string-prefix? s "#x") (try (substring s 2) 16)]
      [(string-prefix? s "#X") (try (substring s 2) 16)]
      [(string-prefix? s "#b") (try (substring s 2) 2)]
      [(string-prefix? s "#B") (try (substring s 2) 2)]
      [(string-prefix? s "#o") (try (substring s 2) 8)]
      [(string-prefix? s "#O") (try (substring s 2) 8)]
      [else (try s 10)]))
  (unless (exact-integer? value)
    (error 'string->integer
           "invalid number '~a' on line ~a"
           s line-number))
  value)

;; ============================================================
;; 固定位段识别
;; ============================================================

(define multi-bit-rx #rx"^([0-9]+)\\.\\.([0-9]+)=(.+)$")
(define single-bit-rx #rx"^([0-9]+)=(.+)$")

(define (looks-like-fixed-field? s)
  (or (regexp-match? multi-bit-rx s)
      (regexp-match? single-bit-rx s)))

(define (parse-fixed-field token line-number)
  (cond
    [(regexp-match multi-bit-rx token)
     => (lambda (m)
          (define hi (string->number (list-ref m 1)))
          (define lo (string->number (list-ref m 2)))
          (define value (string->integer (list-ref m 3) line-number))
          (fixed-field lo hi value))]
    [(regexp-match single-bit-rx token)
     => (lambda (m)
          (define bit (string->number (list-ref m 1)))
          (define value (string->integer (list-ref m 2) line-number))
          (fixed-field bit bit value))]
    [else
     (error 'parse-fixed-field
            "unexpected fixed field '~a' on line ~a"
            token line-number)]))

(provide string->integer
         looks-like-fixed-field?
         parse-fixed-field)
