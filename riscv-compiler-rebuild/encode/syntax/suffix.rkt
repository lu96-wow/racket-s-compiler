#lang racket
;;; encode/syntax/suffix.rkt
;;;
;;; 助记符后缀: .aq / .rl / .aqrl。
;;; 这是唯一的后缀解析点; 其它模块只认 split-aqrl 的结果。

(provide split-aqrl)

(define (string-suffix? s suffix)
  (and (>= (string-length s) (string-length suffix))
       (string=? (substring s (- (string-length s) (string-length suffix))) suffix)))

;; (amoadd.d.aqrl rd rs2 rs1) -> (values 'amoadd.d 1 1)
;; 只认三种规范后缀; .rlaq 之类落到"未知助记符"。
(define (split-aqrl name)
  (define s (symbol->string name))
  (cond
    [(string-suffix? s ".aqrl") (values (string->symbol (substring s 0 (- (string-length s) 5))) 1 1)]
    [(string-suffix? s ".aq")   (values (string->symbol (substring s 0 (- (string-length s) 3))) 1 0)]
    [(string-suffix? s ".rl")   (values (string->symbol (substring s 0 (- (string-length s) 3))) 0 1)]
    [else (values name 0 0)]))
