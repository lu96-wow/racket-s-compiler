#lang racket/base

(require racket/string
         racket/list
         "struct.rkt")

;; ============================================================
;; operand token 解析
;;
;; alias 形如 rs2=rs1：target=rs2，source=rs1。
;; 这里只解析语法，不决定编码方式。
;; ============================================================

(struct alias-binding (target source)
  #:transparent)

(define (alias-token? token)
  (string-contains? token "="))

(define (parse-alias token)
  (define parts (string-split token "="))
  (unless (= (length parts) 2)
    (error 'parse-alias "invalid alias operand: ~a" token))
  (alias-binding (list-ref parts 0) (list-ref parts 1)))

(define (normal-operand-tokens tokens)
  (filter (lambda (token) (not (alias-token? token))) tokens))

(define (instruction-aliases idef)
  (for/list ([token (in-list (instruction-def-operands idef))]
             #:when (alias-token? token))
    (define a (parse-alias token))
    (list (alias-binding-target a)
          (alias-binding-source a))))

(provide alias-binding
         alias-binding?
         alias-binding-target
         alias-binding-source
         alias-token?
         parse-alias
         normal-operand-tokens
         instruction-aliases)
