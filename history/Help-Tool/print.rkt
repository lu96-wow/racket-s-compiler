#lang racket

(define (print-2 var)
  (unless (integer? var)
    (error 'print-2 "expected an integer, given ~e" var))
  (printf "#b~a~n" (number->string var 2)))

(define (print-8 var)
  (unless (integer? var)
    (error 'print-8 "expected an integer, given ~e" var))
  (printf "#o~a~n" (number->string var 8)))

(define (print-16 var)
  (unless (integer? var)
    (error 'print-16 "expected an integer, given ~e" var))
  (printf "#x~a~n" (number->string var 16)))


(provide (all-defined-out))