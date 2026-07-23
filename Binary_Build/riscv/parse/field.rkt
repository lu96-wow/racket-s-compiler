#lang racket

(require racket/string
         "struct.rkt")

;; ============================================================
;; 数字解析
;; ============================================================

(define (string->integer s line-number)
  (define prefixes '["#x" "0x" "#b" "0b" "#o" "0o"])
  (define bases     '(16 16 2 2 8 8))
  (let loop ([ps prefixes] [bs bases])
    (cond
      [(null? ps)
       (or (string->number s 10)
           (error 'string->integer "Invalid number '~a' on line ~a" s line-number))]
      [(string-prefix? s (car ps))
       (or (string->number (substring s (string-length (car ps))) (car bs))
           (error 'string->integer "Invalid number '~a' on line ~a" s line-number))]
      [else (loop (cdr ps) (cdr bs))])))

;; ============================================================
;; 固定字段识别
;; ============================================================

(define (looks-like-multi-bit? s)
  (and (string-contains? s "=")
       (let ([parts (string-split s "=")])
         (and (= (length parts) 2)
              (string-contains? (car parts) "..")
              (let ([bits (string-split (car parts) "..")])
                (and (= (length bits) 2)
                     (string->number (car bits))
                     (string->number (cadr bits))))
              (string->integer (cadr parts) 0)))))

(define (looks-like-single-bit? s)
  (and (string-contains? s "=")
       (let ([parts (string-split s "=")])
         (and (= (length parts) 2)
              (string->number (car parts))
              (string->integer (cadr parts) 0)))))

(define (looks-like-fixed-field? s)
  (or (looks-like-multi-bit? s)
      (looks-like-single-bit? s)))

;; ============================================================
;; 固定字段解析 → fixed-field struct
;; ============================================================

(define (parse-fixed-field token line-number)
  (cond
    [(looks-like-multi-bit? token)
     (match-let ([(list lhs rhs) (string-split token "=")])
       (match-let ([(list high-str low-str) (string-split lhs "..")])
         (fixed-field (string->number high-str)
                      (string->number low-str)
                      (string->integer rhs line-number))))]
    [(looks-like-single-bit? token)
     (match-let ([(list lhs rhs) (string-split token "=")])
       (let ([bit (string->number lhs)])
         (fixed-field bit bit (string->integer rhs line-number))))]
    [else
     (error 'parse-fixed-field
            "Unexpected fixed field format: ~a on line ~a" token line-number)]))

(provide
 string->integer
 looks-like-fixed-field?
 looks-like-multi-bit?
 looks-like-single-bit?
 parse-fixed-field)
