#lang racket

;; Convert a symbol to a UTF-8 byte string.
(define (symbol->bytes sym)
  (string->bytes/utf-8 (symbol->string sym)))

;; Convert a UTF-8 byte string to a symbol.
(define (bytes->symbol bstr)
  (string->symbol (bytes->string/utf-8 bstr)))

(provide symbol->bytes bytes->symbol)